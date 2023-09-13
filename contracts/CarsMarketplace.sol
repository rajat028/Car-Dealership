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
        address contractAddress; // address of the NFTs contract
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
        address _contractAddress,
        uint _carId,
        uint _cost
    ) external {
        // Checks to see if contract is ERC721
        if (!ERC165Checker.supportsInterface(_contractAddress, 0x80ac58cd)) {
            revert NotERC721();
        }
        // Checks to see if the msg.sender is the owner of the car
        address carOwner = IERC721(_contractAddress).ownerOf(_carId);
        if (msg.sender != carOwner) {
            if (
                !IERC721(_contractAddress).isApprovedForAll(
                    carOwner,
                    msg.sender
                )
            ) {
                revert NotAuthorized();
            }
        }

        // Checks to see if contract is approved to manage
        if (
            !IERC721(_contractAddress).isApprovedForAll(
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
            _contractAddress,
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

        address carOwner = getCarOwnerViaContractAddress(
            car.contractAddress,
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

        IERC721(car.contractAddress).safeTransferFrom(
            carOwner,
            msg.sender,
            _carId
        );
        emit CarSaleExecuted(carOwner, msg.sender, _carId);
    }

    function updateCost(
        uint _carId,
        uint _updatedCost
    ) external validCarId(_carId) {
        Car storage car = cars[_carId];
        if (
            checkIfAddressIsNotCarOwner(
                msg.sender,
                car.contractAddress,
                _carId
            )
        ) {
            revert NotAuthorized();
        }
        if (car.cost != _updatedCost) {
            car.cost = _updatedCost;
        }
    }

    function updateAvailability(
        uint _carId,
        bool listed
    ) external validCarId(_carId) {
        Car storage car = cars[_carId];
        if (
            checkIfAddressIsNotCarOwner(
                msg.sender,
                car.contractAddress,
                _carId
            )
        ) {
            revert NotAuthorized();
        }
        cars[_carId].isListed = listed;
    }

    function getCarDetails(
        uint _carId
    ) external view validCarId(_carId) returns (Car memory) {
        return cars[_carId];
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
