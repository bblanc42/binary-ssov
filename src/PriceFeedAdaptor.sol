// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

interface PriceFeedAdaptor {
    function spot() external view returns (uint256 value, bool hasValue);
}
