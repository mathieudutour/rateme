//
//  RatingAlgo.swift
//  rateme
//
//  Created by Mathieu Dutour on 06/01/2018.
//  Copyright © 2018 Mathieu Dutour. All rights reserved.
//

import Foundation

func starsToScore(_ stars: Int) -> Double {
    return Double(stars - 1) / 4.0
}

/**
 * @param raterScore - the score of the person rating the other, between 0 and 1
 * @param rateeScore - the score of the person being rated, between 0 and 1
 * @param rating - note between 1 and 5
 */
func getNewScore(raterScore: Double, rateeScore: Double, rating: Double) -> Double {
    let weight = exp((raterScore - rateeScore) * 5) / 1000
    return (
        rateeScore * (1 - weight)
    ) + (
        starsToScore(rating) * weight
    )
}
