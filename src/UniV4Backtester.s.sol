// SPDX-License-Identifier: MIT
// $ forge script src/UniV4Backtester.s.sol
pragma solidity >=0.8.0;

// import {AutoCompound} from "./hooks/AutoCompound.sol";
import {Script, console} from "forge-std/Script.sol";
import {NoopHook} from "./hooks/NoopHook.sol";
import {PoolEvent, PoolEventType} from "./SUniV4Backtester.sol";
import {IHooks} from "lib/v4-core/src/interfaces/IHooks.sol";
import {PoolManager} from "lib/v4-core/src/PoolManager.sol";
import {Currency} from "lib/v4-core/src/types/Currency.sol";
import {PoolKey} from "lib/v4-core/src/types/PoolKey.sol";
import {IPositionManager} from "lib/v4-periphery/src/interfaces/IPositionManager.sol";

contract UniV4Backtester is Script {
    // Returns mint/swap/burn events from UniV3 pool since pool creation until endDate.
    function getPoolEvents(
        PoolKey memory poolKey,
        uint128 endDate
    ) internal view returns (PoolEvent[] memory) {
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
        // Pool info
        // https://sepolia.uniscan.xyz/address/0xC81462Fec8B23319F288047f8A03A57682a35C1A
        PoolManager poolManager = PoolManager(0xC81462Fec8B23319F288047f8A03A57682a35C1A);
        Currency currency0 = Currency.wrap(0x0000000000000000000000000000000000000000); // native eth on sepolia.unichain
        Currency currency1 = Currency.wrap(0x0000000000000000000000000000000000000001); // Currency.wrap(new ERC20("USDC", "USDC", 6, 100)); // deployedUsdc on sepolia.unichain
        uint24 fee = 3000;
        int24 tickSpacing = 60;
        PoolKey memory poolKey = PoolKey(currency0, currency1, fee, tickSpacing, IHooks(address(0)));

        // Position info
        // https://sepolia.uniscan.xyz/address/0xB433cB9BcDF4CfCC5cAB7D34f90d1a7deEfD27b9
        IPositionManager positionManager = IPositionManager(0xB433cB9BcDF4CfCC5cAB7D34f90d1a7deEfD27b9);
        uint128 positionStartDate = 1620000001;
        uint128 positionInitialLiquidity = 123456789;
        int positionInitialTickLower = -198480;
        int positionInitialTickUpper = -198480;

        // Get and loop through pool events
        PoolEvent[] memory poolEvents = getPoolEvents(poolKey, 1800000000);
        bool isPositionInitialized = false;
        for (uint i = 0; i < poolEvents.length; i++) {
            PoolEvent memory poolEvent = poolEvents[i];
            if (!isPositionInitialized && positionStartDate <= poolEvent.unixTimestamp) {
                // console.log("Initializing position at unixTimestamp=", poolEvents[i].unixTimestamp, ", positionInitialLiquidity=", positionInitialLiquidity, ", positionInitialTickLower=", Strings.toString(positionInitialTickLower), ", positionInitialTickUpper=", Strings.toString(positionInitialTickUpper));
                isPositionInitialized = true;
            }
            if (poolEvent.poolEventType == PoolEventType.MintBurn) {
                // console.log("Mint/Burn event at unixTimestamp %d: minted/burned %d liquidity tokens, tick range [%d, %d]", poolEvent.unixTimestamp, poolEvent.liquidityDelta, poolEvent.tickLower, poolEvent.tickUpper);
            } else if (poolEvent.poolEventType == PoolEventType.Swap) {
                // console.log("Swap event at unixTimestamp %d: swapped %d amount0In, %d amount1In, %d amount0Out, %d amount1Out", poolEvent.unixTimestamp, poolEvent.amount0In, poolEvent.amount1In, poolEvent.amount0Out, poolEvent.amount1Out);
            }
        }
    }
}
