//	
// Copyright © Essential Developer. All rights reserved.
//

import Foundation

struct FriendsCacheItemsServiceAdapter: ItemsService {
    let cache: FriendsCache
    let select: (Friend) -> Void
    
    func loadItems(completion: @escaping (Result<[ItemViewModel], Error>) -> Void) {
        cache.loadFriends { result in
            DispatchQueue.mainAsyncIfNeeded {
                completion(result.map { friends in
                    friends.map { friend in
                        ItemViewModel(friend: friend) {
                            select(friend)
                        }
                    }
                })
            }
        }
    }
}
