//	
// Copyright © Essential Developer. All rights reserved.
//

import UIKit

class MainTabBarController: UITabBarController {
	
    private var friendsCache: FriendsCache!
    
	convenience init(friendsCache: FriendsCache) {
		self.init(nibName: nil, bundle: nil)
        self.friendsCache = friendsCache
		self.setupViewController()
	}

	private func setupViewController() {
		viewControllers = [
			makeNav(for: makeFriendsList(), title: "Friends", icon: "person.2.fill"),
			makeTransfersList(),
			makeNav(for: makeCardsList(), title: "Cards", icon: "creditcard.fill")
		]
	}
	
	private func makeNav(for vc: UIViewController, title: String, icon: String) -> UIViewController {
		vc.navigationItem.largeTitleDisplayMode = .always
		
		let nav = UINavigationController(rootViewController: vc)
		nav.tabBarItem.image = UIImage(
			systemName: icon,
			withConfiguration: UIImage.SymbolConfiguration(scale: .large)
		)
		nav.tabBarItem.title = title
		nav.navigationBar.prefersLargeTitles = true
		return nav
	}
	
	private func makeTransfersList() -> UIViewController {
		let sent = makeSentTransfersList()
		sent.navigationItem.title = "Sent"
		sent.navigationItem.largeTitleDisplayMode = .always
		
		let received = makeReceivedTransfersList()
		received.navigationItem.title = "Received"
		received.navigationItem.largeTitleDisplayMode = .always
		
		let vc = SegmentNavigationViewController(first: sent, second: received)
		vc.tabBarItem.image = UIImage(
			systemName: "arrow.left.arrow.right",
			withConfiguration: UIImage.SymbolConfiguration(scale: .large)
		)
		vc.title = "Transfers"
		vc.navigationBar.prefersLargeTitles = true
		return vc
	}
	
	private func makeFriendsList() -> ListViewController {
		let vc = ListViewController()
        vc.title = "Friends"
        vc.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: vc, action: #selector(addFriend))
        let cache = FriendsCacheItemsServiceAdapter(cache: friendsCache) { [weak vc] friend in
            vc?.select(friend: friend)
        }
        let isPremium = User.shared?.isPremium == true
        let api = FriendsAPIItemsServiceAdapter(
            api: FriendsAPI.shared,
            cache: isPremium ? friendsCache : NullFriendsCache()) { [weak vc] friend in
                    vc?.select(friend: friend)
            }.retry(2)
        vc.service = isPremium ? api.fallback(cache) : api
		return vc
	}
	
	private func makeSentTransfersList() -> ListViewController {
		let vc = ListViewController()
        vc.navigationItem.title = "Sent"
        vc.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Send", style: .done, target: vc, action: #selector(sendMoney))
        vc.service = SentTransferAPIItemsServiceAdapter(
            api: TransfersAPI.shared,
            select: { [weak vc] transfer in
                vc?.select(transfer: transfer)
            }).retry(1)
		return vc
	}
	
	private func makeReceivedTransfersList() -> ListViewController {
		let vc = ListViewController()
        vc.navigationItem.title = "Received"
        vc.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Request", style: .done, target: vc, action: #selector(requestMoney))
        vc.service = ReceivedTransferAPIItemsServiceAdapter(
            api: TransfersAPI.shared,
            select: { [weak vc] transfer in
                vc?.select(transfer: transfer)
            }).retry(1)
		return vc
	}
	
	private func makeCardsList() -> ListViewController {
		let vc = ListViewController()
        vc.title = "Cards"
        vc.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: vc, action: #selector(addCard))
        vc.service = CardsAPIItemsServiceAdapter(
            api: CardAPI.shared,
            select: { [weak vc] card in
                vc?.select(card: card)
        })
		return vc
	}
}

struct ItemsServiceWithFallback: ItemsService {
    let primary: ItemsService
    let fallback: ItemsService
    
    func loadItems(completion: @escaping (Result<[ItemViewModel], Error>) -> Void) {
        primary.loadItems { result in
            switch result {
            case .success:
                completion(result)
            case .failure:
                fallback.loadItems(completion: completion)
            }
        }
    }
}

extension ItemsService {
    func fallback(_ fallback: ItemsService) -> ItemsService {
        ItemsServiceWithFallback(primary: self, fallback: fallback)
    }
    
    func retry(_ retryCount: UInt) -> ItemsService {
        var service: ItemsService = self
        for _ in 0..<retryCount {
            service = service.fallback(self)
        }
        return service
    }
}

struct FriendsAPIItemsServiceAdapter: ItemsService {
    let api: FriendsAPI
    let cache: FriendsCache
    let select: (Friend) -> Void
    
    func loadItems(completion: @escaping (Result<[ItemViewModel], Error>) -> Void) {
        api.loadFriends { result in
            DispatchQueue.mainAsyncIfNeeded {
                completion(result.map { friends in
                    cache.save(friends)
                    
                    return friends.map { friend in
                        ItemViewModel(friend: friend) {
                            select(friend)
                        }
                    }
                })
            }
        }
    }
}

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

//Null object pattern
//an instance sharing a same interface but does nothing!
class NullFriendsCache: FriendsCache {
    override func loadFriends(completion: @escaping (Result<[Friend], Error>) -> Void) {}
}


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

struct SentTransferAPIItemsServiceAdapter: ItemsService {
    let api: TransfersAPI
    let select: (Transfer) -> Void
    
    func loadItems(completion: @escaping (Result<[ItemViewModel], Error>) -> Void) {
        api.loadTransfers { result in
            DispatchQueue.mainAsyncIfNeeded {
                completion(result.map { transfers in
                    return transfers
                        .filter { $0.isSender }
                        .map { item in
                            ItemViewModel(
                                transfer: item,
                                longDateStyle: true) {
                                    select(item)
                                }
                        }
                })
            }
        }
    }
}

struct ReceivedTransferAPIItemsServiceAdapter: ItemsService {
    let api: TransfersAPI
    let select: (Transfer) -> Void
    
    func loadItems(completion: @escaping (Result<[ItemViewModel], Error>) -> Void) {
        api.loadTransfers { result in
            DispatchQueue.mainAsyncIfNeeded {
                completion(result.map { transfers in
                    return transfers
                        .filter { !$0.isSender}
                        .map { item in
                            ItemViewModel(
                                transfer: item,
                                longDateStyle: false) {
                                    select(item)
                                }
                        }
                })
            }
        }
    }
}

