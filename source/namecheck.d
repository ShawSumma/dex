
// https://github.com/phatpiglet/autocorrect

import std.stdio;
import std.algorithm;
import std.range;
import std.conv;
import std.math;

string nameCheck(string text, string[] match) {
    // double winning = 0.4 * text.length;
    double winning = double.infinity;
    string winner = "";
    foreach (i; 0..match.length) {
        string cand = match[i];
        double val = getDist(text, cand, winning) - 1;
        if (val < winning && val != double.infinity) {
            winning = val;
            winner = cand;
        } 
    }
    return winner;
}

double getDist(string txt, string cand, double v) {
    if (txt.length == 0) {
        return min(v+1, cand.length);
    }
    if (cand.length == 0) {
        return min(v+1, txt.length);
    }
    if (abs((cast(long) txt.length) - (cast(long) cand.length)) > v) {
        return v + 1;
    }
    double[][] matrix;
    foreach (i; 0..cand.length+1) {
        matrix ~= [i];
    }
    foreach (i; 0..txt.length+1) {
        matrix[0] ~= i;
    }
    foreach (i; 1..cand.length+1) {
        double cmin = double.infinity;
        double minj = 1;
        double maxj = cand.length + 1;
        if (i > v) {
            minj = v + 1;
        }
        foreach (j; 1..txt.length+1) {
            if (j < minj || j > maxj) {
                if (j < matrix[i].length) {
                    matrix[i][j] = v + 1;
                }
                else {
                    matrix[i] ~= v + 1;
                }
            }
            else if (cand[i-1] == txt[j-1]) {
                if (j < matrix[i].length) {
                    matrix[i][j] = matrix[i-1][j-1];
                }
                else {
                    matrix[i] ~= matrix[i-1][j-1];
                }
            }
            else {
                double val = min(matrix[i-1][j-1], matrix[i][j-1], matrix[i-1][j]) + 1;
                if (j < matrix[i].length) {
                    matrix[i][j] = val;
                }
                else {
                    matrix[i] ~= val;
                }
            }
            if (matrix[i][j] < cmin) {
                cmin = matrix[i][j];
            }
        }
        if (cmin > v) {
            return v + 1;
        }
    }
    return matrix[cand.length][txt.length];
}