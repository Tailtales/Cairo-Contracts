mod erc721;

// use starknet::ContractAddress;

// #[starknet::interface]
// trait IERC721<TContractState> {
//     fn mint(ref self: TContractState) -> u256;
//     fn owner_of(self: @TContractState, id: u256) -> ContractAddress;
// }

// #[starknet::contract]
// mod Puppy {
//     use core::traits::Into;
// use starknet::ContractAddress;
    
//     #[storage]
//     struct Storage {
//         total_minted: u256,
//         total_genosis_available: u256,
//         owner_of: LegacyMap<u256, ContractAddress>
//     }

//     #[abi(embed_v0)]
//     #[external(v0)]
//     impl ERC721Impl of super::IERC721<ContractState>{
//         fn mint(ref self: ContractState) -> u256 {
//              let totalAvailable = self.total_genosis_available.read();

//             assert(totalAvailable > 0, 'genosis nfts sold out');

//             self.total_genosis_available.write(totalAvailable - 1);
            
//             let tokenId = self.total_minted.read() + 1;

            

//             self.total_minted.write(tokenId);

//             tokenId
//         }

//         fn owner_of(self: @ContractState, id: u256) -> ContractAddress {
            
            
//             self.owner_of.read(id)
//         }
//     }

//     #[generate_trait]
//     impl Private of PrivateTrait {
//         fn _generate_random_seed(self: @ContractState) -> u256 {
            
//             // pedersen::pedersen();
//         }
//     }
// }



// // #[starknet::interface]
// // trait IERC721<TContractState>{
// //     fn owner_of(self: @TContractState, token_id: u256) -> ContractAddress;
// // }

// // #[starknet::contract]
// // mod MyNFT {
// //     #[storage]
// //     struct Storage {
// //         #[substorage(v0)]
// //         erc721: ERC721Component::Storage,
// //         #[substorage(v0)]
// //         src5: SRC5Component::Storage
// //     }

// //     #[event]
// //     #[derive(Drop, starknet::Event)]
// //     enum Event {
// //         #[flat]
// //         ERC721Event: ERC721Component::Event,
// //         #[flat]
// //         SRC5Event: SRC5Component::Event
// //     }

// //     #[constructor]
// //     fn constructor(
// //         ref self: ContractState,
// //         recipient: ContractAddress
// //     ) {
// //         let name = 'MyNFT';
// //         let symbol = 'NFT';
// //         let token_id = 1;
// //         let token_uri = 'NFT_URI';

// //         self.erc721.initializer(name, symbol);
// //         self._mint_with_uri(recipient, token_id, token_uri);
// //     }


// //     #[abi(embed_v0)]
// //     impl ERC721Impl<TContractState> of ERC721Component::interface::IERC721<TContractState> {
// //         fn balance_of(
// //             ref self: ContractState,
// //             account: ContractAddress,
// //         ) -> u256 {
// //             0
// //         }
// //     }

// //     #[generate_trait]
// //     impl InternalImpl of InternalTrait {
// //         fn _mint_with_uri(
// //             ref self: ContractState,
// //             recipient: ContractAddress,
// //             token_id: u256,
// //             token_uri: felt252
// //         ) {
// //             // Initialize the ERC721 storage
// //             self.erc721._mint(recipient, token_id);
// //             // Mint the NFT to recipient and set the token's URI
// //             self.erc721._set_token_uri(token_id, token_uri);
// //         }
// //     }
// // }
