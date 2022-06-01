//	
// Copyright © Essential Developer. All rights reserved.
//

import Foundation

struct CardsAPIItemsServiceAdapter: ItemsService {
    let api: CardAPI
    let select: (Card) -> Void
    
    func loadItems(completion: @escaping (Result<[ItemViewModel], Error>) -> Void) {
        api.loadCards { result in
            DispatchQueue.mainAsyncIfNeeded {
                completion(result.map { cards in
                    cards.map { card in
                        ItemViewModel(card: card) {
                            select(card)
                        }
                    }
                })
            }
        }
    }
}
