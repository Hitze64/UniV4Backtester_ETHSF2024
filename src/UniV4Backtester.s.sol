// SPDX-License-Identifier: MIT
// $ forge script src/UniV4Backtester.s.sol
pragma solidity >=0.8.0;

// import {AutoCompound} from "./hooks/AutoCompound.sol";
import {NoopHook} from "./hooks/NoopHook.sol";
import {PoolEvent, PoolEventType} from "./SUniV4Backtester.sol";
import {IHooks} from "lib/v4-core/src/interfaces/IHooks.sol";
import {Currency} from "lib/v4-core/src/types/Currency.sol";
import {PoolKey} from "lib/v4-core/src/types/PoolKey.sol";
import {Script, console} from "forge-std/Script.sol";
import {PoolManager} from "lib/v4-periphery/lib/v4-core/src/PoolManager.sol";

contract UniV4Backtester is Script {
    // Returns mint/swap/burn events from UniV3 pool since pool creation until endDate.
    function getPoolEvents(
        PoolKey calldata poolKey,
        uint128 endDate
    ) external view returns (PoolEvent[] memory) {
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
        Currency currency0 = Currency.wrap(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1); // weth on arbitrum
        Currency currency1 = Currency.wrap(0xaf88d065e77c8cC2239327C5EDb3A432268e5831); // usdc on arbitrum
        uint24 fee = 3000;
        int24 tickSpacing = 60;
        // NoopHook testHook = new NoopHook(new PoolManager(0x0000000000000000000000000000000000000000));
        // PoolKey memory poolKey = PoolKey(currency0, currency1, fee, tickSpacing, new NoopHook(new PoolManager(0x0000000000000000000000000000000000000000)));
        console.log("Hello World!");
    }
}
