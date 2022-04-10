// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import {PriceFeedAdaptor} from "./PriceFeedAdaptor.sol";
import {WethPriceFeed} from "./WethPriceFeed.sol";

contract WethPricefeedAdaptor is PriceFeedAdaptor {
    address public sourceAddress;

    constructor(address _sourceAddress) {
        sourceAddress = _sourceAddress;
    }

    function spot() external view override returns (uint256, bool) {
        (bytes32 _value, bool hasValue) = WethPriceFeed(sourceAddress).peek();
        return (uint256(_value), hasValue);
    }
}
