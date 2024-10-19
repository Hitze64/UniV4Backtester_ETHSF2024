// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

struct MintBurnEvent {
    uint128 unixTimestamp;
    // For burn event, the amount is negative.
    uint128 amount;
    uint128 tickLower;
    uint128 tickUpper;
}

struct SwapEvent {
    uint128 unixTimestamp;
    // For swap events, either amount0 or amount1 will be negative. Negative means taking out of the pool.
    uint128 amount0;
    uint128 amount1;
}

enum PoolEventType { MintBurn, Swap }

struct PoolEvent {
    PoolEventType poolEventType;
    uint128 unixTimestamp;
    uint128 amount;
    uint128 tickLower;
    uint128 tickUpper;
    uint128 amount0;
    uint128 amount1;
}