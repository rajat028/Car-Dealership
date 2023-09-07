// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import "hardhat/console.sol";

contract NFTCarsMarketplace is Ownable {
    // interface id for erc721: 0x80ac58cd
    using Counters for Counters.Counter;
    Counters.Counter private tokenIds; // amount of car NFTs that have been listed

    struct Car {
        address listingOwner;
        address contractAddress; // address of the NFTs contract
        uint256 nativeId; // tokenId of the NFT in its contract
        uint256 cost; // listPrice
        bool isListed; // whether or not the token is avaliable to buy
    }

    // note mileage should not be kept in NFT as it changes

    mapping(address => uint256) balances;
    mapping(uint256 => Car) cars;

    error NotAuthorized();
    error InsufficientFunds();
    error NotAvaliable();
    error TransactionFailed();
    error NotERC721();

    event CarSaleExecuted(address from, address to, uint256 listingId);

    constructor() Ownable() {}

    modifier validTokenId(uint256 _tokenId) {
        if (_tokenId > tokenIds.current() || _tokenId == 0) {
            revert NotAvaliable();
        }
        _;
    }

    function listCar(
        address _contractAddress,
        uint _tokenId,
        uint _cost
    ) external {
        // Checks to see if contract is ERC721
        if (!ERC165Checker.supportsInterface(_contractAddress, 0x80ac58cd)) {
            revert NotERC721();
        }
        // Checks to see if the msg.sender is the owner of the token
        address tokenOwner = IERC721(_contractAddress).ownerOf(_tokenId);
        if (
            msg.sender != tokenOwner ||
            !IERC721(_contractAddress).isApprovedForAll(tokenOwner, msg.sender)
        ) {
            revert NotAuthorized();
        }

        // Checks to see if contract is approved to manage
        if (
            !IERC721(_contractAddress).isApprovedForAll(
                tokenOwner,
                address(this)
            )
        ) {
            revert NotAuthorized();
        }

        tokenIds.increment();
        uint newTokenId = tokenIds.current();
        cars[newTokenId] = Car(
            msg.sender,
            _contractAddress,
            _tokenId,
            _cost,
            true
        );
    }

    function buyCar(uint _tokenId) external payable validTokenId(_tokenId) {
        Car storage car = cars[_tokenId];

        if (!car.isListed) {
            revert NotAvaliable();
        }

        if (msg.value != car.cost) {
            revert InsufficientFunds();
        }

        address carOwner = getCarOwnerViaContractAddress(
            car.contractAddress,
            _tokenId
        );

        if (car.listingOwner != carOwner) {
            revert NotAuthorized();
        }

        car.isListed = false;

        balances[carOwner] += msg.value;

        IERC721(car.contractAddress).safeTransferFrom(
            carOwner,
            msg.sender,
            _tokenId
        );
        emit CarSaleExecuted(carOwner, msg.sender, _tokenId);
    }

    function updateCost(
        uint _tokenId,
        uint _updateCost
    ) external validTokenId(_tokenId) {
        Car storage car = cars[_tokenId];
        if (
            checkIfAddressIsNotCarOwner(msg.sender, car.contractAddress, _tokenId)
        ) {
            revert NotAuthorized();
        }
        if (car.cost != _updateCost) {
            car.cost = _updateCost;
        }
    }

    function makeUnavailable(uint _tokenId) external validTokenId(_tokenId) {
        Car storage car = cars[_tokenId];
        if (
            checkIfAddressIsNotCarOwner(msg.sender, car.contractAddress, _tokenId)
        ) {
            revert NotAuthorized();
        }
        cars[_tokenId].isListed = false;
    }

    function makeAvailable(uint _tokenId, uint _cost) external {
        Car storage car = cars[_tokenId];
        car.isListed = true;
        if (
            checkIfAddressIsNotCarOwner(
                car.listingOwner,
                car.contractAddress,
                _tokenId
            )
        ) {
            car.listingOwner = msg.sender;
        }

        if (_cost != car.cost) {
            car.isListed = true;
        }
    }

    function getCarDetails(
        uint _tokenId
    ) external view validTokenId(_tokenId) returns (Car memory) {
        return cars[_tokenId];
    }

    function getBalance(address _addr) external view returns (uint) {
        return balances[_addr];
    }

    function checkIfAddressIsNotCarOwner(
        address sender,
        address contractAddress,
        uint tokenId
    ) internal view returns (bool) {
        if (sender != getCarOwnerViaContractAddress(contractAddress, tokenId)) {
            return true;
        } else {
            return false;
        }
    }

    function getCarOwnerViaContractAddress(
        address contractAddress,
        uint tokenId
    ) public view returns (address) {
        return IERC721(contractAddress).ownerOf(tokenId);
    }
}
