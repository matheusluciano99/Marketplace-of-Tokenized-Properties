// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {PropertyMarketPlace} from "../src/PropertyMarketPlace.sol";
import {DeployPropertyMarketPlace} from "../script/DeployPropertyMarketPlace.s.sol";
import {PropertyToken} from "../src/PropertyToken.sol";
import {RentedPropertyToken} from "../src/RentedPropertyToken.sol";

contract PropertyMarketPlaceTest is Test {
    PropertyToken propertyToken;
    RentedPropertyToken rentedPropertyToken;
    PropertyMarketPlace propertyMarketPlace;
    string public tokenURI =
        "https://ipfs.io/ipfs/QmX7QnnoWrzhpFtBppf1DUawvik4Da6KzYPStEpuBg28C3";

    address OWNER = makeAddr("owner");
    address RENTER = makeAddr("renter");
    address BUYER = makeAddr("buyer");
    uint256 constant STARTING_BALANCE = 1000 ether;
    uint256 constant PRICE = 100 ether;
    uint256 constant RENT_PRICE_PER_DAY = 1 ether;
    uint256 constant DAYS = 1;

    function setUp() public {
        DeployPropertyMarketPlace deployPropertyMarketPlace = new DeployPropertyMarketPlace();
        (
            propertyToken,
            rentedPropertyToken,
            propertyMarketPlace
        ) = deployPropertyMarketPlace.run();
        vm.deal(OWNER, STARTING_BALANCE); // adding balance to the owner
        vm.deal(RENTER, STARTING_BALANCE); // adding balance to the renter
        vm.deal(BUYER, STARTING_BALANCE); // adding balance to the buyer
    }

    function testListProperty() public {
        vm.prank(OWNER);
        propertyMarketPlace.list(
            PRICE,
            RENT_PRICE_PER_DAY,
            tokenURI,
            true,
            true
        );

        uint256 tokenId = propertyToken.getTokenIdCounter() - 1;

        (
            uint256 price,
            uint256 rentPricePerDay,
            ,
            bool forRent,
            bool forSale,
            address initial_renter
        ) = propertyMarketPlace.properties(tokenId);

        assertEq(price, PRICE);
        assertEq(rentPricePerDay, RENT_PRICE_PER_DAY);
        assertEq(forRent, true);
        assertEq(forSale, true);
        assertEq(initial_renter, address(0));
    }

    function testBuyProperty() public payable {
        vm.prank(OWNER);
        propertyMarketPlace.list(
            PRICE,
            RENT_PRICE_PER_DAY,
            tokenURI,
            true,
            true
        );

        uint256 tokenId = propertyToken.getTokenIdCounter() - 1;

        // Approve the PropertyMarketPlace to transfer the token on the owner's behalf
        vm.prank(OWNER);
        propertyToken.approve(address(propertyMarketPlace), tokenId);

        vm.prank(BUYER);
        propertyMarketPlace.buy{value: PRICE}(tokenId);
        assertEq(propertyToken.ownerOf(tokenId), BUYER);
    }

    function testRentProperty() public {
        vm.prank(OWNER);
        propertyMarketPlace.list(
            PRICE,
            RENT_PRICE_PER_DAY,
            tokenURI,
            true,
            false
        );

        uint256 tokenId = propertyToken.getTokenIdCounter() - 1;

        vm.prank(RENTER);
        propertyMarketPlace.rent{value: RENT_PRICE_PER_DAY}(
            tokenId,
            DAYS,
            tokenURI
        );

        (, , uint256 rentedUntil, , , address renter) = propertyMarketPlace
            .properties(tokenId);

        assertEq(renter, RENTER);
        assertEq(rentedUntil, block.timestamp + 1 days);
    }

    function testExtendRent() public {
        vm.prank(OWNER);
        propertyMarketPlace.list(
            PRICE,
            RENT_PRICE_PER_DAY,
            tokenURI,
            true,
            false
        );

        uint256 tokenId = propertyToken.getTokenIdCounter() - 1;

        vm.prank(RENTER);
        propertyMarketPlace.rent{value: RENT_PRICE_PER_DAY}(
            tokenId,
            DAYS,
            tokenURI
        );
        (, , uint256 old_term, , , ) = propertyMarketPlace.properties(tokenId);

        vm.prank(RENTER);
        propertyMarketPlace.extendRent{value: RENT_PRICE_PER_DAY}(
            tokenId,
            DAYS
        );
        (, , uint256 rentedUntil, , , address renter) = propertyMarketPlace
            .properties(tokenId);

        assertEq(renter, RENTER);
        assertEq(rentedUntil, old_term + 1 days);
    }

    function testEndRentEarlierByOwner() public {
        vm.prank(OWNER);
        propertyMarketPlace.list(
            PRICE,
            RENT_PRICE_PER_DAY,
            tokenURI,
            true,
            false
        );

        uint256 tokenId = propertyToken.getTokenIdCounter() - 1;

        vm.prank(RENTER);
        propertyMarketPlace.rent{value: RENT_PRICE_PER_DAY}(
            tokenId,
            DAYS,
            tokenURI
        );

        vm.prank(OWNER);
        propertyMarketPlace.endRentEarlier(tokenId);

        (, , uint256 rentedUntil, , , address renter) = propertyMarketPlace
            .properties(tokenId);

        assertEq(renter, address(0));
        assertEq(rentedUntil, block.timestamp);
    }

    function testEndRentEarlierByRenter() public {
        vm.prank(OWNER);
        propertyMarketPlace.list(
            PRICE,
            RENT_PRICE_PER_DAY,
            tokenURI,
            true,
            false
        );

        uint256 tokenId = propertyToken.getTokenIdCounter() - 1;

        vm.prank(RENTER);
        propertyMarketPlace.rent{value: RENT_PRICE_PER_DAY}(
            tokenId,
            DAYS,
            tokenURI
        );

        vm.prank(RENTER);
        propertyMarketPlace.endRentEarlier(tokenId);

        (, , uint256 rentedUntil, , , address renter) = propertyMarketPlace
            .properties(tokenId);

        assertEq(renter, address(0));
        assertEq(rentedUntil, block.timestamp);
    }
}
