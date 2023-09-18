// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import "hardhat/console.sol";

contract CarsMarketplace is Ownable {
    // interface id for erc721: 0x80ac58cd
    using Counters for Counters.Counter;
    Counters.Counter public carCount; // amount of car NFTs that have been listed
    
    struct Car {
        address listingOwner;
        address carAddress; // address of the NFTs contract
        uint256 nativeId; // tokenId of the NFT in its contract
        uint256 cost; // listPrice
        bool isListed; // whether or not the car is avaliable to buy
    }

    // note mileage should not be kept in NFT as it changes

    mapping(uint256 => Car) cars;

    error NotAuthorized();
    error ContractNotAuthorized();
    error InsufficientFunds();
    error NotAvaliable();
    error TransactionFailed();
    error NotERC721();
    error InvalidTokenId();

    event CarListed(uint cardId, address carOwner);
    event CarSaleExecuted(address from, address to, uint256 listingId);

    constructor() Ownable() {}

    modifier validCarId(uint256 _carId) {
        if (_carId > carCount.current() || _carId == 0) {
            revert InvalidTokenId();
        }
        _;
    }

    function listCar(
        address _carAddress,
        uint _carId,
        uint _cost
    ) external {
        // Checks to see if contract is ERC721
        if (!ERC165Checker.supportsInterface(_carAddress, 0x80ac58cd)) {
            revert NotERC721();
        }
        // Checks to see if the msg.sender is the owner of the car
        address carOwner = IERC721(_carAddress).ownerOf(_carId);
        if (msg.sender != carOwner) {
            if (
                !IERC721(_carAddress).isApprovedForAll(
                    carOwner,
                    msg.sender
                )
            ) {
                revert NotAuthorized();
            }
        }

        // Checks to see if contract is approved to manage
        if (
            !IERC721(_carAddress).isApprovedForAll(
                carOwner,
                address(this)
            )
        ) {
            revert ContractNotAuthorized();
        }

        carCount.increment();
        uint newCarId = carCount.current();
        cars[newCarId] = Car(
            msg.sender,
            _carAddress,
            _carId,
            _cost,
            true
        );
        emit CarListed(newCarId, carOwner);
    }

    function buyCar(uint _carId) external payable validCarId(_carId) {
        Car storage car = cars[_carId];

        if (!car.isListed) {
            revert NotAvaliable();
        }

        if (msg.value != car.cost) {
            revert InsufficientFunds();
        }

        address carOwner = getCarOwnerViaAddress(
            car.carAddress,
            _carId
        );

        if (car.listingOwner != carOwner) {
            revert NotAuthorized();
        }

        (bool sent, ) = carOwner.call{value: msg.value}("");
        if (!sent) {
            revert TransactionFailed();
        }

        car.isListed = false;
        car.listingOwner = msg.sender;

        IERC721(car.carAddress).safeTransferFrom(
            carOwner,
            msg.sender,
            _carId
        );
        emit CarSaleExecuted(carOwner, msg.sender, _carId);
    }

    function updateCost(
        uint carId,
        uint updatedCost
    ) external validCarId(carId) {
        Car storage car = cars[carId];
        if (
            checkIfAddressIsNotCarOwner(
                msg.sender,
                car.carAddress,
                carId
            )
        ) {
            revert NotAuthorized();
        }
        if (car.cost != updatedCost) {
            car.cost = updatedCost;
        }
    }

    function updateAvailability(
        uint carId,
        bool listed
    ) external validCarId(carId) {
        Car storage car = cars[carId];
        if (
            checkIfAddressIsNotCarOwner(
                msg.sender,
                car.carAddress,
                carId
            )
        ) {
            revert NotAuthorized();
        }
        cars[carId].isListed = listed;
    }

    function getCarDetails(
        uint carId
    ) external view validCarId(carId) returns (Car memory) {
        return cars[carId];
    }

    function checkIfAddressIsNotCarOwner(
        address sender,
        address carAddress,
        uint tokenId
    ) internal view returns (bool) {
        if (sender != getCarOwnerViaAddress(carAddress, tokenId)) {
            return true;
        } else {
            return false;
        }
    }

    function getCarOwnerViaAddress(
        address carAddress,
        uint tokenId
    ) public view returns (address) {
        return IERC721(carAddress).ownerOf(tokenId);
    }
}
