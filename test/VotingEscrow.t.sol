// 1:1 with Hardhat test
pragma solidity 0.8.13;

import './BaseTest.sol';

contract VotingEscrowTest is BaseTest {
    VotingEscrow escrow;

    function setUp() public {
        deployOwners();
        deployCoins();
        mintStables();
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1e21;
        mintVS(owners, amounts);

        VeArtProxy artProxy = new VeArtProxy();
        escrow = new VotingEscrow(address(VSTOKEN), address(artProxy));
    }

    function testFreeze() public {
        VSTOKEN.approve(address(escrow), 1e22);
        uint256 lockDuration = 7 * 24 * 3600; // 1 week
        escrow.create_lock_and_freeze_for(1e20, lockDuration, address(this));
        assertTrue(escrow.isFrozen(1));

        // Try to transferFrom frozen NFT
        vm.expectRevert(abi.encodePacked('frozen'));
        escrow.transferFrom(address(owner), address(owner2), 1);

        // Try to merge frozen NFT
        escrow.create_lock(1e20, lockDuration);
        vm.expectRevert(abi.encodePacked('frozen'));
        escrow.merge(1, 2);

        // Try to split frozen NFT
        uint256[] memory percentages = new uint256[](2);
        percentages[0] = 10;
        percentages[1] = 90;
        vm.expectRevert(abi.encodePacked('frozen'));
        escrow.split(percentages, 1);
    }

    function testWithdrawFrozenAfterUnlock() public {
        VSTOKEN.approve(address(escrow), 1e22);
        uint256 lockDuration = 7 * 24 * 3600; // 1 week
        escrow.create_lock_and_freeze_for(1e20, lockDuration, address(this));
        
        // After unlock time, token should be withdrawable
        vm.warp(block.timestamp + 86400 * 10);
        vm.roll(block.number + 1);

        escrow.withdraw(1);
    }
    
    function testTransferAfterUnfreeze() public {
        VSTOKEN.approve(address(escrow), 1e22);
        uint256 lockDuration = 7 * 24 * 3600; // 1 week
        escrow.create_lock_and_freeze_for(1e20, lockDuration, address(this));

        assertTrue(escrow.isFrozen(1));
        escrow.unfreeze(1);
        assertFalse(escrow.isFrozen(1));
        
        // token should be transferable
        escrow.transferFrom(address(owner), address(owner2), 1);
    }

    function testCreateLock() public {
        VSTOKEN.approve(address(escrow), 1e21);
        uint256 lockDuration = 7 * 24 * 3600; // 1 week

        // Balance should be zero before and 1 after creating the lock
        assertEq(escrow.balanceOf(address(owner)), 0);
        escrow.create_lock(1e21, lockDuration);
        assertEq(escrow.ownerOf(1), address(owner));
        assertEq(escrow.balanceOf(address(owner)), 1);
    }

    function testCreateLockOutsideAllowedZones() public {
        VSTOKEN.approve(address(escrow), 1e21);
        uint256 oneWeek = 7 * 24 * 3600;
        uint256 oneYear = 365 * 24 * 3600;
        vm.expectRevert(abi.encodePacked('Voting lock can be 1 year max'));
        escrow.create_lock(1e21, oneYear + oneWeek);
    }

    function testWithdraw() public {
        VSTOKEN.approve(address(escrow), 1e21);
        uint256 lockDuration = 7 * 24 * 3600; // 1 week
        escrow.create_lock(1e21, lockDuration);

        // Try withdraw early
        uint256 tokenId = 1;
        vm.expectRevert(abi.encodePacked("The lock didn't expire"));
        escrow.withdraw(tokenId);
        // Now try withdraw after the time has expired
        vm.warp(block.timestamp + lockDuration);
        vm.roll(block.number + 1); // mine the next block
        escrow.withdraw(tokenId);

        assertEq(VSTOKEN.balanceOf(address(owner)), 1e21);
        // Check that the NFT is burnt
        assertEq(escrow.balanceOfNFT(tokenId), 0);
        assertEq(escrow.ownerOf(tokenId), address(0));
    }

    function testSplit() public {
        VSTOKEN.approve(address(escrow), 1e21);
        uint256 lockDuration = 7 * 24 * 3600; // 1 week
        escrow.create_lock(1e21, lockDuration);

        // due to rounding errors, we verify the voting power / scale is consistent
        uint256 scale = 100000000;
        uint256 originalBalance = escrow.balanceOfNFT(1);
        uint256 originalVotingPower = escrow.balanceOfNFT(1) / scale;

        uint256[] memory percentages = new uint256[](2);
        percentages[0] = 10;
        percentages[1] = 90;
        escrow.split(percentages, 1);

        // Check that the NFT is burnt
        assertEq(escrow.balanceOfNFT(1), 0);
        assertEq(escrow.ownerOf(1), address(0));

        // Check that 2 new NFTs are created
        assertEq(escrow.balanceOf(address(owner)), 2);
        assertEq(escrow.ownerOf(2), address(owner));
        assertEq(escrow.balanceOfNFT(2) / scale, originalVotingPower * 10 / 100);

        assertEq(escrow.ownerOf(3), address(owner));
        assertEq(escrow.balanceOfNFT(3) / scale, originalVotingPower * 90 / 100);

        // Check that the total balance is consistent
        assertEq(escrow.balanceOfNFT(2) + escrow.balanceOfNFT(3), originalBalance);
    }

    function testCheckTokenURICalls() public {
        // tokenURI should not work for non-existent token ids
        vm.expectRevert(abi.encodePacked("Query for nonexistent token"));
        escrow.tokenURI(999);
        VSTOKEN.approve(address(escrow), 1e21);
        uint256 lockDuration = 7 * 24 * 3600; // 1 week
        escrow.create_lock(1e21, lockDuration);

        uint256 tokenId = 1;
        vm.warp(block.timestamp + lockDuration);
        vm.roll(block.number + 1); // mine the next block

        // Just check that this doesn't revert
        escrow.tokenURI(tokenId);

        // Withdraw, which destroys the NFT
        escrow.withdraw(tokenId);

        // tokenURI should not work for this anymore as the NFT is burnt
        vm.expectRevert(abi.encodePacked("Query for nonexistent token"));
        escrow.tokenURI(tokenId);
    }

    function testConfirmSupportsInterfaceWorksWithAssertedInterfaces() public {
        // Check that it supports all the asserted interfaces.
        bytes4 ERC165_INTERFACE_ID = 0x01ffc9a7;
        bytes4 ERC721_INTERFACE_ID = 0x80ac58cd;
        bytes4 ERC721_METADATA_INTERFACE_ID = 0x5b5e139f;

        assertTrue(escrow.supportsInterface(ERC165_INTERFACE_ID));
        assertTrue(escrow.supportsInterface(ERC721_INTERFACE_ID));
        assertTrue(escrow.supportsInterface(ERC721_METADATA_INTERFACE_ID));
    }

    function testCheckSupportsInterfaceHandlesUnsupportedInterfacesCorrectly() public {
        bytes4 ERC721_FAKE = 0x780e9d61;
        assertFalse(escrow.supportsInterface(ERC721_FAKE));
    }
}
