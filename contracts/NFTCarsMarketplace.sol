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

    modifier onlyTokenOwner(uint256 _tokenId) {
        if (msg.sender != getCarOwner(_tokenId)) {
            revert NotAuthorized();
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

    function buyCar(uint _tokenId) external payable {
        Car storage car = cars[_tokenId];

        if (_tokenId > tokenIds.current() || _tokenId == 0 || !car.isListed) {
            revert NotAvaliable();
        }

        if (msg.value != car.cost) {
            revert InsufficientFunds();
        }

        if (
            car.listingOwner !=
            IERC721(car.contractAddress).ownerOf(car.nativeId)
        ) {
            revert NotAuthorized();
        }

        car.isListed = false;

        balances[getCarOwner(_tokenId)] += msg.value;

        IERC721(car.contractAddress).safeTransferFrom(
            getCarOwner(_tokenId),
            msg.sender,
            _tokenId
        );
        emit CarSaleExecuted(getCarOwner(_tokenId), msg.sender, _tokenId);
    }

    function updateCost(
        uint _tokenId,
        uint _updateCost
    ) external onlyTokenOwner(_tokenId) {
        Car storage car = cars[_tokenId];
        if(msg.sender != IERC721(car.contractAddress).ownerOf(_tokenId)) {
            revert NotAuthorized();
        }
        if (car.cost != _updateCost) {
            car.cost = _updateCost;
        }
    }

    // TODO refactor modifier
    function makeUnavailable(
        uint _tokenId
    ) external onlyTokenOwner(_tokenId) {
        cars[_tokenId].isListed = false;
    }

    function makeAvailable(uint _tokenId, uint _cost) external {
        Car storage car = cars[_tokenId];
        car.isListed = true;
        if (car.listingOwner != getCarOwner(_tokenId)) {
            car.listingOwner = msg.sender;
        }
        if (_cost != car.cost) {
            car.isListed = true;
        }
    }

    function getCarDetails(uint _tokenId) external view returns (Car memory) {
        // Checks to see if the car is avaliable and if the listing Id is valid
        if (_tokenId > tokenIds.current() || _tokenId == 0) {
            revert NotAvaliable();
        }
        return cars[_tokenId];
    }

    function getBalance(address _addr) external view returns (uint) {
        return balances[_addr];
    }

    function getCarOwner(uint _tokenId) public view returns (address) {
        if (_tokenId > tokenIds.current() || _tokenId == 0) {
            revert NotAvaliable();
        }

        Car memory car = cars[_tokenId];
        return IERC721(car.contractAddress).ownerOf(car.nativeId);
    }

    function getCarOwnerViaContractAddress(address contractAddress, uint tokenId)  public view returns (address){
        return IERC721(contractAddress).ownerOf(tokenId);
    }
}
