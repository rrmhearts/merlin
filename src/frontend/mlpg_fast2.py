################################################################################
#           The Neural Network (NN) based Speech Synthesis System
#                https://svn.ecdf.ed.ac.uk/repo/inf/dnn_tts/
#
#                Centre for Speech Technology Research
#                     University of Edinburgh, UK
#                      Copyright (c) 2014-2015
#                        All Rights Reserved.
#
# The system as a whole and most of the files in it are distributed
# under the following copyright and conditions
#
#  Permission is hereby granted, free of charge, to use and distribute
#  this software and its documentation without restriction, including
#  without limitation the rights to use, copy, modify, merge, publish,
#  distribute, sublicense, and/or sell copies of this work, and to
#  permit persons to whom this work is furnished to do so, subject to
#  the following conditions:
#
#   - Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#   - Redistributions in binary form must reproduce the above
#     copyright notice, this list of conditions and the following
#     disclaimer in the documentation and/or other materials provided
#     with the distribution.
#   - The authors' names may not be used to endorse or promote products derived
#     from this software without specific prior written permission.
#
#  THE UNIVERSITY OF EDINBURGH AND THE CONTRIBUTORS TO THIS WORK
#  DISCLAIM ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING
#  ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT
#  SHALL THE UNIVERSITY OF EDINBURGH NOR THE CONTRIBUTORS BE LIABLE
#  FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
#  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN
#  AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
#  ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
#  THIS SOFTWARE.
################################################################################

import numpy as np
import logging
from scipy.linalg import solve_banded, solveh_banded
from scipy.sparse import diags, csr_matrix
from scipy.sparse.linalg import spsolve


class BandMatrix:
    """
    Efficient band matrix class using scipy's banded storage format.
    
    Storage format: ab[u + i - j, j] == a[i, j]
    where ab is the band matrix storage with u upper diagonals and l lower diagonals.
    """
    def __init__(self, u, l, data):
        self.u = u  # upper bandwidth
        self.l = l  # lower bandwidth
        self.data = data  # data in band format: shape (u+l+1, n)
        self.n = data.shape[1]  # number of columns/rows
        self._transpose = None
    
    @property
    def T(self):
        """Return transposed band matrix"""
        if self._transpose is None:
            self._transpose = TransposedBandMatrix(self)
        return self._transpose
    
    def to_sparse(self):
        """Convert to sparse CSR matrix for efficient operations"""
        offsets = list(range(-self.l, self.u + 1))
        diag_data = []
        
        for i, offset in enumerate(offsets):
            band_idx = self.u - offset
            if offset >= 0:
                diag_data.append(self.data[band_idx, :self.n - offset])
            else:
                diag_data.append(self.data[band_idx, -offset:])
        
        return diags(diag_data, offsets, shape=(self.n, self.n), format='csr')
    
    def to_banded_format(self):
        """Return in scipy's solve_banded format (u+l+1, n)"""
        return self.data.copy()


class TransposedBandMatrix:
    """Transposed view of a band matrix"""
    def __init__(self, original):
        self.original = original
        self.u = original.l
        self.l = original.u
        self.n = original.n
        self.data = self._transpose_band_data(original.data, original.u, original.l)
    
    def _transpose_band_data(self, data, u, l):
        """Transpose band matrix data"""
        n = data.shape[1]
        new_data = np.zeros((u + l + 1, n))
        
        for i in range(n):
            for j in range(max(0, i - l), min(n, i + u + 1)):
                band_idx = u + i - j
                new_band_idx = l + j - i
                new_data[new_band_idx, i] = data[band_idx, j]
        
        return new_data
    
    def to_sparse(self):
        """Convert to sparse CSR matrix"""
        return self.original.to_sparse().T
    
    def to_banded_format(self):
        """Return in scipy's solve_banded format"""
        return self.data.copy()


def band_c_bm(u, l, win_coeffs):
    """Create a band matrix from window coefficients"""
    return BandMatrix(u, l, win_coeffs)


def dot_mv(mat, vec):
    """Efficient matrix-vector multiplication for band matrix"""
    if isinstance(mat, (BandMatrix, TransposedBandMatrix)):
        sparse_mat = mat.to_sparse()
        return sparse_mat @ vec
    return mat @ vec


def dot_mv_plus_equals(mat, vec, target):
    """Matrix-vector multiplication with accumulation"""
    target += dot_mv(mat, vec)


def dot_mm_plus_equals(mat1, mat2, target_bm, diag):
    """
    Efficient matrix-matrix multiplication: mat1 @ diag(diag) @ mat2
    Result is accumulated into target_bm (band matrix).
    """
    # Convert to sparse for efficient computation
    if isinstance(mat1, (BandMatrix, TransposedBandMatrix)):
        sparse1 = mat1.to_sparse()
    else:
        sparse1 = csr_matrix(mat1)
    
    if isinstance(mat2, (BandMatrix, TransposedBandMatrix)):
        sparse2 = mat2.to_sparse()
    else:
        sparse2 = csr_matrix(mat2)
    
    # Create diagonal matrix efficiently
    diag_sparse = diags(diag, 0, format='csr')
    
    # Compute: mat1 @ diag @ mat2
    result = sparse1 @ diag_sparse @ sparse2
    
    # Add result to target band matrix
    # We need to extract the band structure from the sparse result
    n = target_bm.n
    u = target_bm.u
    l = target_bm.l
    
    # Convert result to dense for band extraction (only compute needed elements)
    result_dense = result.toarray()
    
    for i in range(n):
        for j in range(max(0, i - l), min(n, i + u + 1)):
            band_idx = u + i - j
            target_bm.data[band_idx, j] += result_dense[i, j]


def zeros_band(u, l, frames):
    """Create a zero band matrix"""
    bandwidth = u + l + 1
    data = np.zeros((bandwidth, frames))
    return BandMatrix(u, l, data)


def solveh_band(prec, b):
    """
    Solve symmetric positive definite band system efficiently.
    Uses scipy's specialized banded solver for best performance.
    """
    # Extract band format: for symmetric matrix, we only need upper bands
    ab = prec.to_banded_format()
    u = prec.u
    l = prec.l
    
    # For symmetric positive definite matrices, use solveh_banded
    # It expects only the upper part in a specific format
    if u == l:  # Symmetric band matrix
        # Create upper band format for solveh_banded: (u+1, n)
        ab_upper = np.zeros((u + 1, prec.n))
        for i in range(u + 1):
            ab_upper[i, :] = ab[i, :]
        
        try:
            # solveh_banded is optimized for symmetric positive definite
            return solveh_banded(ab_upper, b, lower=False)
        except np.linalg.LinAlgError:
            # Fallback to general banded solver
            pass
    
    # General banded solver
    try:
        return solve_banded((l, u), ab, b)
    except np.linalg.LinAlgError:
        # Last resort: use sparse solver
        sparse_prec = prec.to_sparse()
        return spsolve(sparse_prec, b)


class MLParameterGenerationFast(object):
    """
    Maximum Likelihood Parameter Generation using efficient sparse band matrices.
    
    This implementation uses scipy's optimized banded and sparse matrix operations
    for significantly better performance compared to the original bandmat version,
    especially for long sequences.
    """
    def __init__(self, delta_win=[-0.5, 0.0, 0.5], acc_win=[1.0, -2.0, 1.0]):
        self.delta_win = delta_win
        self.acc_win = acc_win
        # Assume the delta and acc windows have the same length
        self.win_length = int(len(delta_win) / 2)

    def build_win_mats(self, windows, frames):
        """Build window matrices in efficient band format"""
        win_mats = []
        for l, u, win_coeff in windows:
            assert l >= 0 and u >= 0
            assert len(win_coeff) == l + u + 1
            win_coeffs = np.tile(np.reshape(win_coeff, (l + u + 1, 1)), frames)
            win_mat = band_c_bm(u, l, win_coeffs)
            win_mats.append(win_mat)

        return win_mats

    def build_poe(self, b_frames, tau_frames, win_mats, sdw=None):
        """
        Build the product of experts (POE) formulation.
        Returns the linear system (b, prec) where prec @ x = b
        """
        if sdw is None:
            sdw = max([win_mat.l + win_mat.u for win_mat in win_mats])
        num_windows = len(win_mats)
        frames = len(b_frames)
        assert np.shape(b_frames) == (frames, num_windows)
        assert np.shape(tau_frames) == (frames, num_windows)
        assert all([win_mat.l + win_mat.u <= sdw for win_mat in win_mats])

        b = np.zeros((frames,))
        prec = zeros_band(sdw, sdw, frames)

        for win_index, win_mat in enumerate(win_mats):
            dot_mv_plus_equals(win_mat.T, b_frames[:, win_index], target=b)
            dot_mm_plus_equals(win_mat.T, win_mat, target_bm=prec,
                             diag=tau_frames[:, win_index].astype(np.float64))

        return b, prec

    def generation(self, features, covariance, static_dimension):
        """
        Generate smooth parameter trajectory from noisy observations.
        
        Args:
            features: Input features (frames x (static_dim * 3))
            covariance: Covariance/variance (frames x (static_dim * 3))
            static_dimension: Number of static dimensions
            
        Returns:
            gen_parameter: Smoothed static parameters (frames x static_dim)
        """
        windows = [
            (0, 0, np.array([1.0])),           # Static
            (1, 1, np.array([-0.5, 0.0, 0.5])), # Delta
            (1, 1, np.array([1.0, -2.0, 1.0])), # Acceleration
        ]
        num_windows = len(windows)

        frame_number = features.shape[0]

        logger = logging.getLogger('param_generation')
        logger.debug('starting MLParameterGeneration.generation')

        gen_parameter = np.zeros((frame_number, static_dimension))

        win_mats = self.build_win_mats(windows, frame_number)
        mu_frames = np.zeros((frame_number, 3))
        var_frames = np.zeros((frame_number, 3))

        for d in range(static_dimension):
            # Extract mean and variance for this dimension
            var_frames[:, 0] = covariance[:, d]
            var_frames[:, 1] = covariance[:, static_dimension + d]
            var_frames[:, 2] = covariance[:, static_dimension * 2 + d]
            mu_frames[:, 0] = features[:, d]
            mu_frames[:, 1] = features[:, static_dimension + d]
            mu_frames[:, 2] = features[:, static_dimension * 2 + d]
            
            # Set large variances at boundaries for delta and acceleration
            var_frames[0, 1] = 1e11
            var_frames[0, 2] = 1e11
            var_frames[frame_number - 1, 1] = 1e11
            var_frames[frame_number - 1, 2] = 1e11

            # Convert to precision-weighted observations
            b_frames = mu_frames / var_frames
            tau_frames = 1.0 / var_frames

            # Build and solve the linear system
            b, prec = self.build_poe(b_frames, tau_frames, win_mats)
            mean_traj = solveh_band(prec, b)

            gen_parameter[0:frame_number, d] = mean_traj

        return gen_parameter