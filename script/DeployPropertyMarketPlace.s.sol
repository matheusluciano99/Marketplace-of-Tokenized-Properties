// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {PropertyMarketPlace} from "../src/PropertyMarketPlace.sol";
import {PropertyToken} from "../src/PropertyToken.sol";
import {RentedPropertyToken} from "../src/RentedPropertyToken.sol";

contract DeployPropertyMarketPlace is Script {
    function run()
        external
        returns (PropertyToken, RentedPropertyToken, PropertyMarketPlace)
    {
        // deploy the PPTs, rPPTs and the marketplace
        vm.startBroadcast();
        PropertyToken propertyToken = new PropertyToken();
        RentedPropertyToken rentedPropertyToken = new RentedPropertyToken();
        PropertyMarketPlace propertyMarketPlace = new PropertyMarketPlace(
            propertyToken,
            rentedPropertyToken
        );

        rentedPropertyToken.setPropertyMarketPlace(
            address(propertyMarketPlace)
        );
        vm.stopBroadcast();

        return (propertyToken, rentedPropertyToken, propertyMarketPlace);
    }
}
