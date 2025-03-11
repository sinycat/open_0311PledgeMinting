// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RNT is ERC20, Ownable {
    constructor() ERC20("Reward Native Token", "RNT") Ownable(msg.sender) {
        _mint(msg.sender, 1_000_000 * 10**18); // 初始发行 1,000,000 RNT (精度 18)
    }

    // 管理员可以铸造新的代币（可选功能）
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}