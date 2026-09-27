import Foundation

actor OpenFoodFactsService {
    static let shared = OpenFoodFactsService()
    private let baseURL = "https://world.openfoodfacts.org"
    private let fields = "code,product_name,brands,nutriments,serving_size,serving_quantity,image_small_url"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        // Open Food Facts asks apps to identify themselves
        config.httpAdditionalHeaders = ["User-Agent": "FitDrop/1.0 (iOS)"]
        self.session = URLSession(configuration: config)
    }

    // MARK: - Barcode Lookup

    func fetchProduct(barcode: String) async throws -> OFFProduct {
        let cleaned = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty,
              let url = URL(string: "\(baseURL)/api/v3/product/\(cleaned).json?fields=\(fields)") else {
            throw OFFError.invalidURL
        }
        let (data, response) = try await load(url)
        // v3 answers an unknown barcode with 404 and a JSON body
        if response.statusCode == 404 { throw OFFError.productNotFound }
        guard response.statusCode == 200 else { throw OFFError.networkError }
        return try Self.decodeProduct(data, barcode: cleaned)
    }

    static func decodeProduct(_ data: Data, barcode: String) throws -> OFFProduct {
        guard let decoded = try? JSONDecoder().decode(OFFProductResponse.self, from: data) else {
            throw OFFError.decodingError
        }
        guard let product = decoded.product, product.productName?.isEmpty == false || product.nutriments != nil else {
            throw OFFError.productNotFound
        }
        guard product.code == nil else { return product }
        return OFFProduct(
            code: decoded.code ?? barcode,
            productName: product.productName,
            brands: product.brands,
            nutriments: product.nutriments,
            servingSize: product.servingSize,
            servingQuantity: product.servingQuantity,
            imageSmallUrl: product.imageSmallUrl
        )
    }

    // MARK: - Search

    func searchProducts(query: String, page: Int = 1) async throws -> [OFFProduct] {
        var components = URLComponents(string: "\(baseURL)/cgi/search.pl")
        components?.queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "page_size", value: "30"),
            URLQueryItem(name: "fields", value: fields),
        ]
        guard let url = components?.url else { throw OFFError.invalidURL }
        let (data, response) = try await load(url)
        guard response.statusCode == 200 else { throw OFFError.networkError }
        return try Self.decodeSearch(data)
    }

    /// Keeps products that have a name and calories, without duplicates.
    static func decodeSearch(_ data: Data) throws -> [OFFProduct] {
        guard let decoded = try? JSONDecoder().decode(OFFSearchResponse.self, from: data) else {
            throw OFFError.decodingError
        }
        var seen = Set<String>()
        return decoded.products.filter { product in
            guard product.nutriments?.energyKcal100g != nil,
                  product.productName?.isEmpty == false else { return false }
            return seen.insert(product.id).inserted
        }
    }

    private func load(_ url: URL) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw OFFError.networkError
        }
        guard let http = response as? HTTPURLResponse else { throw OFFError.networkError }
        return (data, http)
    }
}

enum OFFError: LocalizedError {
    case invalidURL
    case networkError
    case productNotFound
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "That barcode or search couldn't be read."
        case .networkError: return "Couldn't reach the food database. Check your connection and try again."
        case .productNotFound: return "This product isn't in the food database yet. You can add it manually."
        case .decodingError: return "The food database sent data we couldn't read."
        }
    }
}
