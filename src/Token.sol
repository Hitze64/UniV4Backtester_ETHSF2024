// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract WBTC is ERC20 {
    constructor() ERC20("Wrapped BTC", "BTC") {
        _mint(msg.sender, 1000000 * (10 ** uint256(decimals())));
    }
}

contract WETH is ERC20 {
    constructor() ERC20("Wrapped ETH", "WETH") {
        _mint(msg.sender, 1000000 * (10 ** uint256(decimals())));
    }
}
