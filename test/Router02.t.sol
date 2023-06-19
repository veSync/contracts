// 1:1 with Hardhat test
pragma solidity 0.8.13;

import "./BaseTest.sol";

contract Router02Test is BaseTest {
    function deployPairCoins() public {
        vm.warp(block.timestamp + 1 weeks); // put some initial time in

        deployOwners();
        deployCoins();
        mintStables();
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 2e25;
        amounts[1] = 1e25;
        amounts[2] = 1e25;
        mintYFX(owners, amounts);
    }

    function routerAddLiquidity() public {
        deployPairFactoryAndRouter();
        deployPairCoins();

        USDC.approve(address(router02), USDC_100K);
        YFX.approve(address(router02), TOKEN_100K);
        router02.addLiquidity(
            address(YFX),
            address(USDC),
            true,
            TOKEN_100K,
            USDC_100K,
            TOKEN_100K,
            USDC_100K,
            address(owner),
            block.timestamp
        );
    }

    function testRouterSwapWithFee() public {
        routerAddLiquidity();

        Router02.route[] memory routes = new Router02.route[](1);
        routes[0] = Router02.route(address(USDC), address(YFX), true);

        uint256[] memory outputAmounts = router02.getAmountsOut(USDC_1, routes);
        uint expectedAmountOut = (outputAmounts[1] * 90) / 100; // 10% tax
        console2.log(expectedAmountOut);
        USDC.approve(address(router02), USDC_1);
        uint balanceBefore = YFX.balanceOf(address(owner));
        router02.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            USDC_1,
            expectedAmountOut,
            routes,
            address(owner),
            block.timestamp
        );
        uint balanceAfter = YFX.balanceOf(address(owner));
        assertEq(balanceAfter - balanceBefore - 1, expectedAmountOut); // -1 because of numerical error
    }
}
