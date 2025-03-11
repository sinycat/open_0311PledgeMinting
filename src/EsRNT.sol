// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract EsRNT is ERC20, ERC20Burnable, Ownable {
    constructor() ERC20("Escrowed RNT", "esRNT") Ownable(msg.sender) {}

    // 只有管理员（质押合约）可以铸造 esRNT
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}