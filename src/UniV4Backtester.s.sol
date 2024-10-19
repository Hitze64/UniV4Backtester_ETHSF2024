// SPDX-License-Identifier: MIT
// $ forge script src/UniV4Backtester.s.sol
pragma solidity >=0.8.0;

import {PoolEvent} from "./SUniV4Backtester.sol";
import {PoolKey} from "lib/v4-core/src/types/PoolKey.sol";
import {Script, console} from "forge-std/Script.sol";

contract UniV4Backtester is Script {
    // Returns mint/swap/burn events from UniV3 pool since pool creation until endDate.
    function getPoolEvents(
        PoolKey calldata poolKey,
        uint128 endDate
    ) external view returns (PoolEvent[] memory poolEvents) {
        // TODO @gnarlycow
    }

    function run() public {
        // TODO @tommyzhao451
        console.log("Hello World!");
    }
}
