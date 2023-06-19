// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

contract TestTaxableToken {
    string public name;
    string public symbol;
    uint8 public decimals;

    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowance;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        allowance[msg.sender][_spender] = _value;
        return true;
    }

    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal returns (bool) {
        uint256 taxAmount = amount / 10; // 10% tax
        uint256 transferAmount = amount - taxAmount;

        require(balances[from] >= amount, "Insufficient balance");
        balances[from] -= amount;
        balances[to] += transferAmount;
        return true;
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        return _transfer(msg.sender, recipient, amount);
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public returns (bool) {
        uint256 allowed_from = allowance[_from][msg.sender];
        if (allowed_from != type(uint).max) {
            allowance[_from][msg.sender] -= _value;
        }
        return _transfer(_from, _to, _value);
    }

    function mint(address to, uint256 value) public {
        _mint(to, value);
    }

    function burn(address from, uint256 value) public {
        _burn(from, value);
    }

    function _mint(address to, uint256 amount) internal {
        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balances[to] += amount;
        }
    }

    function _burn(address from, uint256 amount) internal {
        balances[from] -= amount;
    }
}
