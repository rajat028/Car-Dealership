const { expect } = require("chai");
const hre = require("hardhat");
const {
  loadFixture
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe("Car", function () {
	const NAME = "Car"
	const SYMBOL = "CARNFT"

	async function deployTokenFixture() {
		;[deployer, buyer, _] = await ethers.getSigners()

		const cars = await ethers.deployContract("Cars", [NAME, SYMBOL])
		await cars.waitForDeployment()
		return { cars, NAME, SYMBOL }
	}

	it("should return correct name & symbol", async () => {
		const { cars } = await loadFixture(deployTokenFixture)

		expect(await cars.name()).to.equal(NAME)
		expect(await cars.symbol()).to.equal(SYMBOL)
	})

    it("should return correct owner", async () => {
        const { cars } = await loadFixture(deployTokenFixture)
        expect(await cars.owner()).equal(deployer.address)
    })

    it("should be able to mint cars nft", async () => {
        const { cars } = await loadFixture(deployTokenFixture)

        // Given
        const tokenURI = "tokenURI"
        const tokenSupplyBefore = await cars.tokenSupply()

        // When
        await cars.safeMint(tokenURI)

        // Then
        const tokenSupplyAfter = await cars.tokenSupply()
        expect(tokenSupplyAfter).greaterThan(tokenSupplyBefore)
        expect(tokenSupplyAfter).eq(tokenSupplyBefore + BigInt(1))
    })

    it("Sets token URI", async () => {
        const { cars } = await loadFixture(deployTokenFixture);
        await cars.connect(buyer).safeMint("testURI");
  
        expect(await cars.tokenURI(1)).to.equal("testURI");
      });

    it("should throw error when non token owner tries to burn nft", async () => {
        const { cars } = await loadFixture(deployTokenFixture)

        // Given
        const tokenURI = "tokenURI"
        await cars.safeMint(tokenURI)

        // When & Then
        const tokenId = await cars.tokenSupply()
        await expect(cars.connect(buyer).burn(tokenId)).to.be.revertedWithCustomError(
            cars,
            `NotApproved`
        )
    })

    it("should be able to burn cars nft by owner or approved address", async () => {
        const { cars } = await loadFixture(deployTokenFixture)
        // Given
        const tokenURI = "tokenURI"
        await cars.safeMint(tokenURI)
        const tokenSupplyBefore = await cars.tokenSupply()

        // When
        await cars.burn(tokenSupplyBefore)

        // Then
        const tokenSupplyAfter = await cars.tokenSupply()
        expect(tokenSupplyAfter).lessThan(tokenSupplyBefore)
        expect(tokenSupplyAfter).eq(tokenSupplyBefore - BigInt(1))
    })
})