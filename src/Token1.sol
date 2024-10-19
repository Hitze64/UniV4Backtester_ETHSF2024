// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract Token1 is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {
        _mint(msg.sender, 1000000 * (10 ** uint256(decimals())));
    }
}