import Foundation

actor OpenFoodFactsService {
    static let shared = OpenFoodFactsService()
    private let baseURL = "https://world.openfoodfacts.org"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Barcode Lookup

    func fetchProduct(barcode: String) async throws -> OFFProduct {
        let urlString = "\(baseURL)/api/v3/product/\(barcode).json?fields=product_name,brands,nutriments,serving_size,image_small_url"
        guard let url = URL(string: urlString) else {
            throw OFFError.invalidURL
        }
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OFFError.networkError
        }
        let decoded = try JSONDecoder().decode(OFFProductResponse.self, from: data)
        guard decoded.status == 1, let product = decoded.product else {
            throw OFFError.productNotFound
        }
        return product
    }

    // MARK: - Search

    func searchProducts(query: String, page: Int = 1) async throws -> [OFFProduct] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "\(baseURL)/cgi/search.pl?search_terms=\(encoded)&search_simple=1&action=process&json=1&page=\(page)&page_size=20&fields=product_name,brands,nutriments,serving_size,image_small_url"
        guard let url = URL(string: urlString) else {
            throw OFFError.invalidURL
        }
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OFFError.networkError
        }
        let decoded = try JSONDecoder().decode(OFFSearchResponse.self, from: data)
        return decoded.products.filter { product in
            product.nutriments?.energyKcal100g != nil
        }
    }
}

enum OFFError: LocalizedError {
    case invalidURL
    case networkError
    case productNotFound
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .networkError: return "Network error. Check your connection."
        case .productNotFound: return "Product not found in database."
        case .decodingError: return "Could not read product data."
        }
    }
}
