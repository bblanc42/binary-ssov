// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import {WethPriceFeed} from "./WethPriceFeed.sol";

contract WethPricefeedSimulator is WethPriceFeed {
    uint256 public value;

    event SetValue(uint256 value);

    constructor(uint256 _startValue) {
        value = _startValue;
        emit SetValue(value);
    }

    function setValue(uint256 _value) public {
        value = _value;
        emit SetValue(value);
    }

    function peek() public view override returns (uint256 _value) {
        _value = uint256(value);
    }
}
