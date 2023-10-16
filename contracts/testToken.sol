// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC20, Ownable {
    constructor() ERC20("MyToken", "MTK") {
        mint(msg.sender,88888888888888888888);
        mint(0x54cA1E40F102585f08b687d86209Cff583D90dfd,8888888888888888888888);
        mint(0x7FD6F1D62296654CC0C1B0C6dbCCa54678da4DE0,8888888888888888888888);
        mint(0xaD2f1fe0846910E1F8390679Dfc5E6Eaf7541C80,8888888888888888888888);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
