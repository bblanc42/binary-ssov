// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import {WethPriceFeed} from "./WethPriceFeed.sol";
import "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract WethPricefeedAdaptor is WethPriceFeed {
    AggregatorV3Interface internal priceFeed;

    constructor(address _priceFeed) {
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    function peek() public view override returns (uint256 _value) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return uint256(price);
    }
}
