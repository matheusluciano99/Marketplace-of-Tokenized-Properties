// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {KeeperCompatibleInterface} from "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";
import {PropertyToken} from "./PropertyToken.sol";
import {RentedPropertyToken} from "./RentedPropertyToken.sol";

contract PropertyMarketPlace is KeeperCompatibleInterface {
    PropertyToken public propertyToken;
    RentedPropertyToken public rentedPropertyToken;

    // struct to represent the Property
    struct Property {
        uint256 price;
        uint256 rentPricePerDay;
        uint256 rentedUntil;
        bool forRent;
        bool forSale;
        address renter;
    }

    mapping(uint256 => Property) public properties; // Mapping a tokenId to the property
    mapping(uint256 => uint256) public rentTokens; // Mapping from property tokenId to rent tokenId
    mapping(uint256 => address) public rentTokenToPropertyOwner; // Mapping from rent tokenId to property owner

    uint256 public tokenIdCounter = 0;

    // Logging important events
    event PropertyListedForRent(uint256 indexed tokenId, uint256 rentPrice);

    event PropertyListedForSale(uint256 indexed tokenId, uint256 price);

    event PropertyListedBothForSaleAndRent(
        uint256 indexed tokenId,
        uint256 price,
        uint256 rentPrice
    );

    event PropertyBought(
        uint256 indexed tokenId,
        address indexed buyer,
        uint256 price
    );

    event PropertyRented(
        uint256 indexed tokenId,
        address indexed renter,
        uint256 rentPrice,
        uint256 _days
    );

    event PropertyDelisted(uint256 indexed tokenId);

    event RentEnded(
        uint256 indexed tokenId,
        address indexed owner,
        address indexed renter
    );

    event RentTokenBurned(uint256 indexed tokenId, uint256 rentTokenId);

    constructor(
        PropertyToken _propertyToken,
        RentedPropertyToken _rentedPropertyToken
    ) {
        propertyToken = _propertyToken;
        rentedPropertyToken = _rentedPropertyToken;
    }

    function getPropertyOwnerForRentToken(
        uint256 rentTokenId
    ) public view returns (address) {
        return rentTokenToPropertyOwner[rentTokenId];
    }

    // listing the token
    function list(
        uint256 _price,
        uint256 _rentPricePerDay,
        string memory _tokenURI,
        bool _forRent,
        bool _forSale
    ) public {
        uint256 tokenId = propertyToken.mint(msg.sender, _tokenURI);

        properties[tokenId] = Property({
            price: _price,
            rentPricePerDay: _rentPricePerDay,
            rentedUntil: 0,
            forRent: _forRent,
            forSale: _forSale,
            renter: address(0)
        });

        if (_forRent && _forSale) {
            emit PropertyListedBothForSaleAndRent(
                tokenId,
                _price,
                _rentPricePerDay
            );
        } else if (_forSale) {
            emit PropertyListedForSale(tokenId, _price);
        } else if (_forRent) {
            emit PropertyListedForRent(tokenId, _rentPricePerDay);
        }

        tokenIdCounter++; // count the number of tokens listed
    }

    // remove token from listing
    function deList(uint256 tokenId) public {
        Property storage property = properties[tokenId];
        require(
            msg.sender == propertyToken.ownerOf(tokenId),
            "Only owner can delist"
        );

        property.forSale = false;
        property.forRent = false;

        // delete properties[tokenId];
        // burn???
        // tokenIdCounter--; ???
        // Emit remove from listing event

        emit PropertyDelisted(tokenId);
    }

    function buy(uint256 tokenId) public payable {
        Property storage property = properties[tokenId];
        address owner = propertyToken.ownerOf(tokenId);
        address buyer = msg.sender;

        require(msg.sender != owner, "Owner cannot buy own property");
        require(property.forSale, "Property not for sale!");

        propertyToken.safeTransferFrom(owner, buyer, tokenId);
        payable(owner).transfer(msg.value);

        emit PropertyBought(tokenId, buyer, property.price);
        deList(tokenId);
    }

    // set for rent
    function rent(
        uint256 tokenId,
        uint256 _days,
        string memory _tokenURI
    ) public payable {
        Property storage property = properties[tokenId];
        uint256 rentPrice = property.rentPricePerDay * _days;
        address owner = propertyToken.ownerOf(tokenId);

        require(msg.value == rentPrice, "Incorrect rent amount");
        require(msg.sender != owner, "Owner cannot rent own property");
        require(property.forRent, "Property not for rent.");
        require(
            block.timestamp > property.rentedUntil,
            "Property already rented."
        );

        uint256 rentTokenId = rentedPropertyToken.mint(msg.sender, _tokenURI);
        rentTokens[tokenId] = rentTokenId;
        rentTokenToPropertyOwner[rentTokenId] = owner;

        property.rentedUntil = block.timestamp + (_days * 1 days);
        property.forRent = false;
        property.renter = msg.sender;

        emit PropertyRented(tokenId, msg.sender, rentPrice, _days);
    }

    // extends the term
    function extendRent(uint256 tokenId, uint256 _days) public payable {
        Property storage property = properties[tokenId];
        uint256 rentPrice = property.rentPricePerDay * _days;
        require(
            msg.sender == property.renter,
            "Only the current renter can extend the rent!"
        );
        require(
            block.timestamp < property.rentedUntil,
            "Rent period already ended!"
        );
        require(msg.value == rentPrice, "Incorrect rent amount");

        property.rentedUntil += (_days * 1 days);

        emit PropertyRented(tokenId, msg.sender, rentPrice, _days);
    }

    // burns an expired token
    // implement chainlink keepers
    function burnExpiredRentToken(uint256 tokenId) public {
        Property storage property = properties[tokenId];
        require(
            block.timestamp > property.rentedUntil,
            "Rent period not yet expired"
        );

        uint256 rentTokenId = rentTokens[tokenId];
        rentedPropertyToken.burn(rentTokenId, propertyToken.ownerOf(tokenId));

        property.renter = address(0);
        property.rentedUntil = block.timestamp;

        emit RentTokenBurned(tokenId, rentTokenId);
    }

    function setForRent(uint256 tokenId, uint256 _rentPricePerDay) public {
        Property storage property = properties[tokenId];
        address owner = propertyToken.ownerOf(tokenId);

        require(msg.sender == owner, "Only owner can set for rent");

        property.forRent = true;
        property.rentPricePerDay = _rentPricePerDay;
    }

    function unSetForRent(uint256 tokenId) public {
        Property storage property = properties[tokenId];
        address owner = propertyToken.ownerOf(tokenId);

        require(msg.sender == owner, "Only owner can unset for rent");

        property.forRent = false;
    }

    function setForSale(uint256 tokenId, uint256 _price) public {
        Property storage property = properties[tokenId];
        address owner = propertyToken.ownerOf(tokenId);

        require(msg.sender == owner, "Only owner can set for sale");

        property.forSale = true;
        property.price = _price;
    }

    function unSetForSale(uint256 tokenId) public {
        Property storage property = properties[tokenId];
        address owner = propertyToken.ownerOf(tokenId);

        require(msg.sender == owner, "Only owner can unset for sale");

        property.forSale = false;
    }

    // ends a term before the expected
    // implemment penalties and deadline
    function endRentEarlier(uint256 tokenId) public {
        Property storage property = properties[tokenId];
        address owner = propertyToken.ownerOf(tokenId);
        address renter = property.renter;

        require(
            msg.sender == owner || msg.sender == renter,
            "Only owner or renter can end rent"
        );
        require(
            property.rentedUntil > block.timestamp,
            "Property is not rented"
        );
        // if msg.sender == owner
        // implement fines and a deadline

        // if msg.sender == renter
        // implement something else

        uint256 rentTokenId = rentTokens[tokenId];
        rentedPropertyToken.burn(rentTokenId, propertyToken.ownerOf(tokenId));

        property.renter = address(0);
        property.rentedUntil = block.timestamp;

        emit RentEnded(tokenId, msg.sender, renter);
    }

    // Chainlink Keepers
    function checkUpkeep(
        bytes calldata
    ) external view override returns (bool upkeepNeeded, bytes memory) {
        upkeepNeeded = false;
        for (uint256 tokenId = 0; tokenId < tokenIdCounter; tokenId++) {
            if (block.timestamp > properties[tokenId].rentedUntil) {
                upkeepNeeded = true;
                break;
            }
        }
        return (upkeepNeeded, "");
    }

    function performUpkeep(bytes calldata) external override {
        for (uint256 tokenId = 0; tokenId < tokenIdCounter; tokenId++) {
            if (block.timestamp > properties[tokenId].rentedUntil) {
                burnExpiredRentToken(tokenId);
            }
        }
    }
}
