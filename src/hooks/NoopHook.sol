// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IPoolManager} from "lib/v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "lib/v4-periphery/lib/v4-core/src/libraries/Hooks.sol";
import {BaseHook} from "lib/v4-periphery/src/base/hooks/BaseHook.sol";
import {PoolKey} from "lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";
import {BeforeSwapDelta} from "lib/v4-periphery/lib/v4-core/src/types/BeforeSwapDelta.sol";
import {Currency} from "lib/v4-periphery/lib/v4-core/src/types/Currency.sol";

contract NoopHook is BaseHook {
    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

    function getHookPermissions() public pure virtual override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: false,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
        // // For 0xdaE97900D4B184c5D2012dcdB658c008966466DD
        // return Hooks.Permissions({
        //     beforeInitialize: true,
        //     afterInitialize: false,
        //     beforeAddLiquidity: false,
        //     afterAddLiquidity: true,
        //     beforeRemoveLiquidity: true,
        //     afterRemoveLiquidity: false,
        //     beforeSwap: true,
        //     afterSwap: true,
        //     beforeDonate: false,
        //     afterDonate: true,
        //     beforeSwapReturnDelta: true,
        //     afterSwapReturnDelta: true,
        //     afterAddLiquidityReturnDelta: false,
        //     afterRemoveLiquidityReturnDelta: true
        // });
    }

    // function beforeSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata params, bytes calldata)
    //     external
    //     override
    //     returns (bytes4, BeforeSwapDelta, uint24)
    // {
    //     // NoOp only works on exact-input swaps
    //     if (params.amountSpecified < 0) {
    //         // take the input token so that v3-swap is skipped...
    //         Currency input = params.zeroForOne ? key.currency0 : key.currency1;
    //         uint256 amountTaken = uint256(-params.amountSpecified);
    //         poolManager.mint(address(this), input.toId(), amountTaken);

    //         // to NoOp the exact input, we return the amount that's taken by the hook
    //         return (BaseHook.beforeSwap.selector, toBeforeSwapDelta(amountTaken.toInt128(), 0), 0);
    //     }
    //     else {
    //         return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO, 0);
    //     }
    // }
}