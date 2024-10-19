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
        // This is a placeholder implementation. Replace it with the actual implementation.
        PoolEvent[] memory poolEvents = new PoolEvent[](5);
        poolEvents[0] = PoolEvent(PoolEventType.MintBurn, 1620000000, 1000000000000000000, -198480, -193500, 0, 0);
        poolEvents[1] = PoolEvent(PoolEventType.MintBurn, 1620000123, 1000000000000000000, -198180, -193200, 0, 0);
        poolEvents[2] = PoolEvent(PoolEventType.Swap, 1620000456, 0, 0, 0, 7890123, -1234567);
        poolEvents[3] = PoolEvent(PoolEventType.Swap, 1620000789, 0, 0, 0, -123456, 987654);
        poolEvents[4] = PoolEvent(PoolEventType.MintBurn, 1620009876, -1000000000000000000, -198480, -193500, 0, 0);
        return poolEvents;
    }

    function run() public {
        // TODO @tommyzhao451
        console.log("Hello World!");
    }
}
