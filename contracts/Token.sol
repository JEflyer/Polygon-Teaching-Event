//SPDX-License-Identifier:GLWTPL
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IStaking{
    function update(uint256 amount) external returns(bool);
}

contract Token is ERC20 {
    
    address private admin;

    address private staking;

    constructor() ERC20("Name","Sym"){
        admin = msg.sender;

        _mint(admin, 200 * 10 ** 18);
    }

    function initialize(address _staking) external {
        require(staking == address(0),"ERR:AS");//AS => Already Set
        require(_staking != address(0),"ERR:NSA");//NSA => Null Staking Address

        require(msg.sender == admin,"ERR:NA");//NA => Null Admin

        staking = _staking;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            uint256 burnFee = (amount/100);
            _balances[from] = fromBalance - amount;
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            _balances[to] += amount - burnFee;
            _totalSupply -= burnFee;
        }
        require(IStaking(staking).update(burnFee), "ERR:FU");//FU => Failed Update

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    function Mint(address to, uint256 amount) external returns(bool) {
        require(msg.sender == staking,"ERR:NA");//NA => Not Allowed

    }
}   