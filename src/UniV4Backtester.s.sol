// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {PoolEvent} from "./SUniV4Backtester.sol";

contract UniV4Backtester {
    // Returns mint/swap/burn events from UniV3 pool since pool creation until endDate.
    function getPoolEvents(/*add poolKey,*/uint128 endDate) external view returns (PoolEvent[] memory poolEvents) {
        // TODO
    }
}