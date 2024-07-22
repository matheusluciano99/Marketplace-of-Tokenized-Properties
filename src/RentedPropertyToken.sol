// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {PropertyMarketPlace} from "./PropertyMarketPlace.sol";

contract RentedPropertyToken is ERC721URIStorage {
    uint256 private _tokenIdCounter;
    PropertyMarketPlace public propertyMarketPlace;

    constructor() ERC721("RentedPropertyToken", "rPPT") {
        _tokenIdCounter = 0;
    }

    function setPropertyMarketPlace(address _propertyMarketPlace) external {
        propertyMarketPlace = PropertyMarketPlace(_propertyMarketPlace);
    }

    // mints the rent token directly to the renter
    function mint(address to, string memory tokenURI) public returns (uint256) {
        uint256 rentTokenId = _tokenIdCounter;
        _tokenIdCounter++;
        _mint(to, rentTokenId);
        _setTokenURI(rentTokenId, tokenURI);
        return rentTokenId;
    }

    function burn(uint256 rentTokenId, address owner) public {
        address propertyOwner = propertyMarketPlace
            .getPropertyOwnerForRentToken(rentTokenId);
        require(
            msg.sender == address(propertyMarketPlace),
            "Caller is not the marketplace!"
        );
        require(owner == propertyOwner, "Caller is not the property owner!");
        _burn(rentTokenId);
    }

    function getTokenIdCounter() external view returns (uint256) {
        return _tokenIdCounter;
    }
}
