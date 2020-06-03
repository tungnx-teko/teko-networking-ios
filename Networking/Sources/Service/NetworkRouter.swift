//
//  NetworkService.swift
//  NetworkLayer
//
//  Created by Malcolm Kumwenda on 2018/03/07.
//  Copyright © 2018 Malcolm Kumwenda. All rights reserved.
//

import Foundation

public typealias NetworkRouterCompletion<T> = (_ data: T?,_ error: NetworkError?) -> ()

public protocol NetworkRouter: class {
    associatedtype EndPoint: EndPointType
    func request<T: Decodable>(_ route: EndPoint, responseType: T.Type, completion: @escaping NetworkRouterCompletion<T>)
    func cancel()
}

public enum NetworkError: String, Error {
    case authenticationError = "Authentication"
    case badRequest
    case outdated
    case failed
    case noData
    case unableToDecode
    case undefined
    case encodingFailed
    case missingURL
}

enum Result<V> {
    case success
    case failure(V)
}

public class Router<EndPoint: EndPointType>: NetworkRouter {
    private var task: URLSessionTask?
    
    public init () {}
    
    public func request<T: Decodable>(_ route: EndPoint, responseType: T.Type, completion: @escaping NetworkRouterCompletion<T>) {
        let session = URLSession.shared
        do {
            let request = try self.buildRequest(from: route)
            task = session.dataTask(with: request, completionHandler: { (data, response, error) in
                if error != nil {
                    completion(nil, .undefined)
                }
                if let response = response as? HTTPURLResponse {
                    print(response)
                    let result = self.handleNetworkResponse(response)
                    
                    switch result {
                    case .success:
                        guard let responseData = data else {
                            completion(nil, .noData)
                            return
                        }
                        do {
                            let jsonData = try JSONSerialization.jsonObject(with: responseData, options: .mutableContainers)
                            print(jsonData)
                            let object = try JSONDecoder().decode(responseType, from: responseData)
                            completion(object, nil)
                        } catch {
                            completion(nil, NetworkError.unableToDecode) // unable to decode
                        }
                    case .failure(let error):
                        completion(nil, error)
                    }
                }
            })
        } catch {
            print(error)
            completion(nil, .undefined)
        }
        self.task?.resume()
    }
    
    public func cancel() {
        self.task?.cancel()
    }
    
    fileprivate func buildRequest(from route: EndPoint) throws -> URLRequest {
        var request = URLRequest(url: route.baseURL.appendingPathComponent(route.path),
                                 cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                                 timeoutInterval: 10.0)
        request.httpMethod = "POST"
        switch route.task {
        case .request:
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        case .requestParametersAndHeaders(let bodyParameters, let bodyEncoding, let urlParameters, let additionHeaders):
            do {
                switch bodyEncoding {
                case .jsonEncoding:
                    try JSONParameterEncoder().encode(urlRequest: &request, with: bodyParameters ?? Parameters())
                case .urlEncoding:
                    try URLParameterEncoder().encode(urlRequest: &request, with: urlParameters ?? Parameters())
                }
            } catch {
                throw error
            }
        }
        return request
    }
    
    fileprivate func handleNetworkResponse(_ response: HTTPURLResponse) -> Result<NetworkError> {
        switch response.statusCode {
        case 200...299: return .success
        case 401...500: return .failure(.authenticationError)
        case 501...599: return .failure(.badRequest)
        case 600: return .failure(.outdated)
        default: return .failure(.failed)
        }
    }
    
}

