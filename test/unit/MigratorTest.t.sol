// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "../BaseTest.sol";
import "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";

contract Unit is Test {
    function testMigrator() external {
        Migrator migrator = new Migrator(
            0x6EA5a344d116Db8949348648713760836D60fC5a,
            address(new MultiVault("MultiVault", 1)),
            address(new RatiosStrategy()),
            0xAEb6bdd95c502390db8f52c8909F703E9Af6a346,
            address(new SymbioticWithdrawalQueue(address(new Claimer()))),
            1 hours
        );

        address vault = 0xB908c9FE885369643adB5FBA4407d52bD726c72d;
        ProxyAdmin proxyAdmin =
            ProxyAdmin(address(uint160(uint256(vm.load(vault, ERC1967Utils.ADMIN_SLOT)))));

        vm.startPrank(proxyAdmin.owner());
        migrator.stageMigration(proxyAdmin, vault);

        address vaultAdmin = IAccessControlEnumerable(vault).getRoleMember(0x00, 0);
        skip(1 hours);
        proxyAdmin.transferOwnership(address(migrator));
        migrator.executeMigration(proxyAdmin, vaultAdmin);

        vm.stopPrank();
    }

    function testMigrator2() external {
        Migrator migrator = new Migrator(
            0x6EA5a344d116Db8949348648713760836D60fC5a,
            address(new MultiVault("MultiVault", 1)),
            address(new RatiosStrategy()),
            0xAEb6bdd95c502390db8f52c8909F703E9Af6a346,
            address(new SymbioticWithdrawalQueue(address(new Claimer()))),
            1 hours
        );

        address vault = 0xB908c9FE885369643adB5FBA4407d52bD726c72d;
        ProxyAdmin proxyAdmin =
            ProxyAdmin(address(uint160(uint256(vm.load(vault, ERC1967Utils.ADMIN_SLOT)))));

        address vaultAdmin = IAccessControlEnumerable(vault).getRoleMember(0x00, 0);

        vm.startPrank(proxyAdmin.owner());
        migrator.stageMigration(proxyAdmin, vault);

        skip(1 hours);
        proxyAdmin.transferOwnership(address(migrator));
        migrator.cancelMigration(proxyAdmin);
        migrator.stageMigration(proxyAdmin, vault);

        vm.expectRevert();
        migrator.executeMigration(proxyAdmin, vaultAdmin);

        skip(1 hours);
        vm.expectRevert();
        migrator.executeMigration(proxyAdmin, vaultAdmin);

        proxyAdmin.transferOwnership(address(migrator));
        migrator.executeMigration(proxyAdmin, vaultAdmin);

        vm.stopPrank();
    }

    function testMigrator3() external {
        Migrator migrator = new Migrator(
            0x6EA5a344d116Db8949348648713760836D60fC5a,
            address(new MultiVault("MultiVault", 1)),
            address(new RatiosStrategy()),
            0xAEb6bdd95c502390db8f52c8909F703E9Af6a346,
            address(new SymbioticWithdrawalQueue(address(new Claimer()))),
            1 hours
        );

        address vault = 0x7b31F008c48EFb65da78eA0f255EE424af855249;
        ProxyAdmin proxyAdmin =
            ProxyAdmin(address(uint160(uint256(vm.load(vault, ERC1967Utils.ADMIN_SLOT)))));

        address owner = proxyAdmin.owner();
        vm.startPrank(owner);
        vm.expectRevert("Migrator: previous migration is incomplete");
        migrator.stageMigration(proxyAdmin, vault);

        address[] memory users = new address[](36);
        {
            users[0] = 0x420f5A4a8EA8905f9E00DBf4c7a13f568B183feA;
            users[1] = 0x69bec889c9C35fDF7D345A17f943280265d6d108;
            users[2] = 0x9Cc7940432714C53DD737597F0a146e22bFf4D3f;
            users[3] = 0x7c17dfd5A8abEA430423F1D6b1629523d3FDeE89;
            users[4] = 0x93638d77043333A578440CF9bCa7594BfbDC3D02;
            users[5] = 0xB75D1dd551533b868978B0F06BF51313c63DC2b1;
            users[6] = 0x7f49f40c57f643301e413cae9725323a72F2aa1f;
            users[7] = 0xa1BBEFE3eF2eB57964a4be511bF817fEcE4D39BD;
            users[8] = 0xDbD5aad8Ec1953EF617Aac5aFbB0FaF9489eC82e;
            users[9] = 0x41b67B86fcC2e6E68cd89A8d6188F4150694247b;
            users[10] = 0x35B2FDae54E3e85498B71dEB5E6094F4b1e94E86;
            users[11] = 0x026d6e38D2cc2Ad7E68BcE942fE7B643383F652D;
            users[12] = 0x14b6BdBA3e0e8be8AfBa2017887f4f9b2c24D67E;
            users[13] = 0xdCC8f181295cFCD9Ce83f8bE87Cb16902C2e1aEf;
            users[14] = 0x9f7B3205A279D7818FeB441C91e43a3DB58bA2ab;
            users[15] = 0x804b97B9917571aAaeC9f0424e1115Db8a6240E7;
            users[16] = 0xca3eB4EF85Eb0f24d37375434bf30b0cB25b4F37;
            users[17] = 0x2a2b7015C8B308aa45cB4D6A5fEE46770d92Ce1A;
            users[18] = 0x803EAdbd7dB2d489154C542e567FA413915486c1;
            users[19] = 0xA0583F12F9a433754a0589d2299eEb4d96B05240;
            users[20] = 0x9a708589a9a0966EF2596096573204EfdA629685;
            users[21] = 0x5b9acC7C98634067AABD3279852a608e3A5a9Ae8;
            users[22] = 0x221574d41e9875B2679dcd3eB974484bCae17FBb;
            users[23] = 0xc82f87301a294f0941Bc4789560744cDE2916108;
            users[24] = 0xc3481dB3075f320b7CC0564be38D18432f8549BB;
            users[25] = 0x0B19C911423D96CE981C49E98A44E6a5E43711B2;
            users[26] = 0x66eea8629940F8AE98Ad7F7F2d02f018375B07f3;
            users[27] = 0x2E1531c10054b22d2564e020Dc3a95dcC0d940cc;
            users[28] = 0x22efec9Fee90555FB9D0791c631cBB1212AB2F70;
            users[29] = 0xad79579eEceF31f4719426232D7b527B17b84f85;
            users[30] = 0x7eAC1b0D1a3b5C455CE16d5adF971ec687844f4b;
            users[31] = 0xf71bCE84216905B9d5543Af709C5a5a35778abE3;
            users[32] = 0x5c3c4faF96DA5cD480d92fEBf2AC3ec39ecB1f79;
            users[33] = 0x5c0b2fA42E5f37F0b3043fdE611c48F1f1a133A0;
            users[34] = 0x1bB222B161df43a1E9Da4260658c50E3c32612eE;
            users[35] = 0x7b31F008c48EFb65da78eA0f255EE424af855249;
        }

        ISimpleLRT(vault).migrateMultiple(users);
        migrator.stageMigration(proxyAdmin, vault);

        skip(1 hours);
        proxyAdmin.transferOwnership(address(migrator));
        migrator.cancelMigration(proxyAdmin);
        migrator.stageMigration(proxyAdmin, vault);

        address vaultAdmin = IAccessControlEnumerable(vault).getRoleMember(0x00, 0);
        vm.expectRevert();
        migrator.executeMigration(proxyAdmin, vaultAdmin);

        skip(1 hours);
        vm.expectRevert();
        migrator.executeMigration(proxyAdmin, vaultAdmin);

        proxyAdmin.transferOwnership(address(migrator));
        migrator.executeMigration(proxyAdmin, vaultAdmin);

        vm.stopPrank();
    }
}

interface ISimpleLRT {
    function migrateMultiple(address[] calldata users) external;
}
