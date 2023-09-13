const { expect } = require("chai");
const { ethers}  = require("hardhat")
const { loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { formatEther, parseEther } = require("ethers");
// const { ZeroAddress } = require("ethers");

describe("Car", function () {
	const NAME = "Car"
	const SYMBOL = "CARNFT"
	const TOKEN_ID = 1
	const LISTING_ID = 1
	const ONE_ETH = ethers.parseEther("1")
	let carsMarketplace
	let cars

	async function deployContractFixture() {
		;[owner, tokenHolder] = await ethers.getSigners()

		cars = await ethers.deployContract("Cars", [NAME, SYMBOL])
		await cars.waitForDeployment()
		;[deployer, , tokenBuyer, otherUser] = await ethers.getSigners()

		carsMarketplace = await ethers.deployContract("CarsMarketplace")
		await carsMarketplace.waitForDeployment()

		await cars.connect(tokenHolder).safeMint("testURI")

		return { tokenHolder, tokenBuyer, otherUser, cars, deployer, carsMarketplace, owner }
	}

    async function getBalance(address) {
        const provider = ethers.provider;
        const balanceWei = await provider.getBalance(address);
		return balanceWei
      }

	describe("Deployment", () => {
		it("Sets owner upon constructor", async () => {
			const { deployer, carsMarketplace } = await loadFixture(deployContractFixture)

			expect(await carsMarketplace.owner()).to.equal(deployer.address)
		})
	})

	describe("Listing Car", () => {
		it("should throw error if contract address in not ERC721", async () => {
			const { carsMarketplace } = await loadFixture(deployContractFixture)
			await expect(
				carsMarketplace.listCar(carsMarketplace.getAddress(), TOKEN_ID, ONE_ETH)
			).to.revertedWithCustomError(carsMarketplace, "NotERC721")
		})

		it("should throw error if sender is not token owner or sender didn't approved by the owner", async () => {
			const { carsMarketplace, cars } = await loadFixture(deployContractFixture)
			await expect(
				carsMarketplace.listCar(cars.getAddress(), TOKEN_ID, ONE_ETH)
			).to.revertedWithCustomError(carsMarketplace, "NotAuthorized")
		})

		it("should throw error if contract didn't approved by the owner", async () => {
			const { carsMarketplace, cars, tokenHolder } = await loadFixture(deployContractFixture)
			await expect(
				carsMarketplace.connect(tokenHolder).listCar(cars.getAddress(), TOKEN_ID, ONE_ETH)
			).to.revertedWithCustomError(carsMarketplace, "ContractNotAuthorized")
		})

		it("car owner should be able to list car", async () => {
			const { carsMarketplace, cars, tokenHolder } = await loadFixture(deployContractFixture)
			await cars.connect(tokenHolder).setApprovalForAll(carsMarketplace.getAddress(), true)
			const tokenIdBefore = await carsMarketplace.carCount()

			await carsMarketplace.connect(tokenHolder).listCar(cars.getAddress(), TOKEN_ID, ONE_ETH)

			const tokenIdAfter = await carsMarketplace.carCount()

			expect(tokenIdAfter).greaterThan(tokenIdBefore)
			expect(tokenIdAfter).eq(tokenIdBefore + BigInt(1))

			const carDeatils = await carsMarketplace.getCarDetails(tokenIdAfter)
			expect(carDeatils.listingOwner).eq(tokenHolder.address)
			expect(carDeatils.contractAddress).eq(await cars.getAddress())
			expect(carDeatils.nativeId).eq(TOKEN_ID)
			expect(carDeatils.cost).eq(ONE_ETH)
			expect(carDeatils.isListed).eq(true)
		})

		it("should emit CarListed when car listed successfuly", async () => {
			//Given
			const { carsMarketplace, cars, tokenHolder, tokenBuyer } = await loadFixture(
				deployContractFixture
			)
			await cars.connect(tokenHolder).setApprovalForAll(carsMarketplace.getAddress(), true)
			const carIdBefore = await carsMarketplace.carCount()
            //When & Then
            await expect(carsMarketplace.connect(tokenHolder).listCar(cars.getAddress(), TOKEN_ID, ONE_ETH))
				.to.emit(carsMarketplace, "CarListed")
				.withArgs(carIdBefore + BigInt(1), tokenHolder.address)
		})
	})

	describe("Buy Car", () => {
		it("should throw error in case invalid tokenId", async () => {
			//Given
			const { carsMarketplace, cars, tokenHolder, tokenBuyer } = await loadFixture(
				deployContractFixture
			)
			await listCar(tokenHolder, cars.getAddress())
			const invalidTokenId = 2

			//When & Then
			await expect(
				carsMarketplace.connect(tokenBuyer).buyCar(invalidTokenId)
			).to.revertedWithCustomError(carsMarketplace, "InvalidTokenId")
		})

		it("should throw error in case car is not listed", async () => {
			//Given
			const { carsMarketplace, cars, tokenHolder, tokenBuyer } = await loadFixture(
				deployContractFixture
			)
			await listCar(tokenHolder, cars.getAddress())
			await carsMarketplace.connect(tokenHolder).updateAvailability(TOKEN_ID, false)
			//When & Then
			await expect(
				carsMarketplace.connect(tokenBuyer).buyCar(TOKEN_ID)
			).to.revertedWithCustomError(carsMarketplace, "NotAvaliable")
		})

		it("should throw error when cost mismatch", async () => {
			//Given
			const { carsMarketplace, cars, tokenHolder, tokenBuyer } = await loadFixture(
				deployContractFixture
			)
			await listCar(tokenHolder, cars.getAddress())

			//When & Then
			await expect(
				carsMarketplace.connect(tokenBuyer).buyCar(TOKEN_ID, { value: ethers.parseEther("0.5") })
			).to.revertedWithCustomError(carsMarketplace, "InsufficientFunds")
		})

        it("should throw error when cost mismatch", async () => {
			//Given
			const { carsMarketplace, cars, tokenHolder, tokenBuyer } = await loadFixture(
				deployContractFixture
			)
			await listCar(tokenHolder, cars.getAddress())
            await cars.connect(tokenHolder).safeTransferFrom(tokenHolder.address, tokenBuyer.address, TOKEN_ID)

			//When & Then
			await expect(
				carsMarketplace.connect(tokenBuyer).buyCar(TOKEN_ID, { value: ONE_ETH })
			).to.revertedWithCustomError(carsMarketplace, "NotAuthorized")
		})

        it("should be able to buy car nft", async () => {
            //Given
			const { carsMarketplace, cars, tokenHolder, tokenBuyer } = await loadFixture(
				deployContractFixture
			)
			await listCar(tokenHolder, cars.getAddress())
            const balanceBeforeSale = await getBalance(tokenHolder.address)

            //When
            await carsMarketplace.connect(tokenBuyer).buyCar(TOKEN_ID, { value: ONE_ETH })

            //Then
            expect(await cars.ownerOf(TOKEN_ID)).to.equal(tokenBuyer.address);
            const carDeatils = await carsMarketplace.getCarDetails(TOKEN_ID)
            expect(carDeatils.isListed).eq(false)
            const balanceAfterSale = await getBalance(tokenHolder.address)
            expect(balanceAfterSale).gt(balanceBeforeSale)
        })
	})

    describe("Cost Update", () => {
        it("should throw error if tokenId is invalid", async ()=> {
            //Given
            const updatedAmount = ethers.parseEther("2")
            const invalidTokenId = 2
			const { carsMarketplace, cars, tokenHolder, tokenBuyer } = await loadFixture(
				deployContractFixture
			)
            await listCar(tokenHolder, cars.getAddress())

            //When & Then
			await expect(
				carsMarketplace.connect(tokenHolder).updateCost(invalidTokenId, updatedAmount)
			).to.revertedWithCustomError(carsMarketplace, "InvalidTokenId")
        })

        it("should throw error if non car owner tries to update cost", async ()=> {
            //Given
            const updatedAmount = ethers.parseEther("2")
			const { carsMarketplace, cars, tokenHolder, tokenBuyer } = await loadFixture(
				deployContractFixture
			)
            await listCar(tokenHolder, cars.getAddress())
            const tokenId= await carsMarketplace.carCount()

            //When & Then
			await expect(
				carsMarketplace.connect(tokenBuyer).updateCost(tokenId, updatedAmount)
			).to.revertedWithCustomError(carsMarketplace, "NotAuthorized")
        })

        it("should be able to update car cost successfuly", async ()=> {
            //Given
            const updatedAmount = ethers.parseEther("2")
			const { carsMarketplace, cars, tokenHolder, tokenBuyer } = await loadFixture(
				deployContractFixture
			)
            await listCar(tokenHolder, cars.getAddress())
            const tokenId = await carsMarketplace.carCount()

            //When 
            await carsMarketplace.connect(tokenHolder).updateCost(tokenId, updatedAmount)

            //Then
            const carDeatils = await carsMarketplace.getCarDetails(tokenId)
            expect(carDeatils.cost).eq(updatedAmount)
        })
    })

    describe("Car Unavailable", async() => {
        it("should throw error if tokenId is invalid", async ()=> {
            //Given
            const invalidTokenId = 2
			const { carsMarketplace, cars, tokenHolder } = await loadFixture(
				deployContractFixture
			)
            await listCar(tokenHolder, cars.getAddress())

            //When & Then
			await expect(
				carsMarketplace.connect(tokenHolder).updateAvailability(invalidTokenId, false)
			).to.revertedWithCustomError(carsMarketplace, "InvalidTokenId")
        })

        it("should throw error if non car owner tries to update availability", async ()=> {
            //Given
			const { carsMarketplace, cars, tokenHolder, tokenBuyer } = await loadFixture(
				deployContractFixture
			)
            await listCar(tokenHolder, cars.getAddress())
            const tokenId= await carsMarketplace.carCount()

            //When & Then
			await expect(
				carsMarketplace.connect(tokenBuyer).updateAvailability(tokenId, false)
			).to.revertedWithCustomError(carsMarketplace, "NotAuthorized")
        })

        it("should be able to uodate car availability", async ()=> {
            //Given
			const { carsMarketplace, cars, tokenHolder } = await loadFixture(
				deployContractFixture
			)
            await listCar(tokenHolder, cars.getAddress())
            const tokenId = await carsMarketplace.carCount()
            let listed = false

            //When 
            await carsMarketplace.connect(tokenHolder).updateAvailability(tokenId, listed)

            //Then
            const carDeatils = await carsMarketplace.getCarDetails(tokenId)
            expect(carDeatils.isListed).eq(false)
        })
    })

	async function listCar(lister, contractAddress) {
		await cars.connect(lister).setApprovalForAll(carsMarketplace.getAddress(), true)
		await carsMarketplace.connect(lister).listCar(contractAddress, TOKEN_ID, ONE_ETH)
	}
})