// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

struct MintBurnEvent {
    uint128 unixTimestamp;
    // For burn event, the amount is negative.
    int amount;
    int tickLower;
    int tickUpper;
}

struct SwapEvent {
    uint128 unixTimestamp;
    // For swap events, either amount0 or amount1 will be negative. Negative means taking out of the pool.
    int amount0;
    int amount1;
}

enum PoolEventType { MintBurn, Swap }

struct PoolEvent {
    PoolEventType poolEventType;
    uint128 unixTimestamp;
    int amount;
    int tickLower;
    int tickUpper;
    int amount0;
    int amount1;
}