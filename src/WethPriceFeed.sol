// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

interface WethPriceFeed {
    function peek() external view returns (bytes32 _value, bool _hasValue);
}
