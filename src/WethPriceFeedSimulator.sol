// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import {WethPriceFeed} from "./WethPriceFeed.sol";

contract WethPricefeedSimulator is WethPriceFeed {
    uint256 public value;
    bool public hasValue;

    event SetValue(uint256 value, bool hasValue);

    constructor(uint256 _startValue) {
        value = _startValue;
        hasValue = true;
        emit SetValue(value, hasValue);
    }

    function setValue(uint256 _value, bool _hasValue) public {
        value = _value;
        hasValue = _hasValue;
        emit SetValue(value, hasValue);
    }

    function peek() public view override returns (uint256 _value) {
        _value = uint256(value);
    }
}