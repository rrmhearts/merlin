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

import logging
import numpy as np

class MLParameterGeneration(object):
    """
    Generates acoustic feature trajectories from mean and variance sequences
    using maximum likelihood parameter generation (MLPG).

    This implementation uses standard NumPy for all matrix operations and does
    not require the 'bandmat' library. It constructs full matrices, which may
    be less memory and computationally efficient than a banded matrix approach
    for very long sequences, but is simpler and has no special dependencies.
    """

    def __init__(self, delta_win=[-0.5, 0.0, 0.5], acc_win=[1.0, -2.0, 1.0]):
        """
        Initializes the parameter generator with delta and acceleration windows.

        Args:
            delta_win (list): Coefficients for the delta window.
            acc_win (list): Coefficients for the acceleration window.
        """
        self.delta_win = np.array(delta_win, dtype=np.float64)
        self.acc_win = np.array(acc_win, dtype=np.float64)

    def _build_win_mats(self, frames):
        """
        Constructs the window matrices for static, delta, and acceleration features.

        Args:
            frames (int): The number of frames in the sequence.

        Returns:
            list: A list containing the static (I), delta (W_d), and
                  acceleration (W_a) window matrices as NumPy arrays.
        """
        windows_config = [
            (0, 0, np.array([1.0])),  # Static feature window (identity)
            (1, 1, self.delta_win),   # Delta feature window
            (1, 1, self.acc_win),     # Acceleration feature window
        ]

        win_mats = []
        for l, u, win_coeff in windows_config:
            mat = np.zeros((frames, frames), dtype=np.float64)
            for i, coeff in enumerate(win_coeff):
                offset = i - l
                if frames > abs(offset):
                    diag = np.full(frames - abs(offset), coeff)
                    mat += np.diag(diag, k=offset)
            win_mats.append(mat)

        return win_mats

    def _build_poe(self, b_frames, tau_frames, win_mats):
        """
        Builds the 'b' vector and precision matrix 'P' for the system of equations.

        The system to be solved is P * c = b, where 'c' is the target static
        feature trajectory.

        Args:
            b_frames (np.ndarray): The b vectors (mu/var) for each stream.
            tau_frames (np.ndarray): The precision (1/var) for each stream.
            win_mats (list): The list of window matrices [W_s, W_d, W_a].

        Returns:
            tuple: A tuple containing the vector b and the precision matrix P.
        """
        frames = b_frames.shape[0]
        b = np.zeros(frames, dtype=np.float64)
        P = np.zeros((frames, frames), dtype=np.float64)

        for i, W in enumerate(win_mats):
            # b = sum(W_i^T * (mu_i / var_i))
            b += W.T @ b_frames[:, i]

            # P = sum(W_i^T * diag(1 / var_i) * W_i)
            tau_i = tau_frames[:, i]
            # An efficient way to compute W.T @ D @ W is (W.T * tau) @ W
            # where broadcasting handles the diagonal matrix multiplication.
            P += (W.T * tau_i) @ W

        return b, P

    def generation(self, features, covariance, static_dimension):
        """
        Generates parameter trajectories from predicted features and covariances.

        Args:
            features (np.ndarray): A (frames, num_features) array of feature means.
                                   Expected to be ordered [static, delta, acc].
            covariance (np.ndarray): A (frames, num_features) array of feature variances.
            static_dimension (int): The dimensionality of the static features.

        Returns:
            np.ndarray: A (frames, static_dimension) array of generated parameters.
        """
        frame_number = features.shape[0]
        logger = logging.getLogger('param_generation')
        logger.debug('Starting ML parameter generation')

        gen_parameter = np.zeros((frame_number, static_dimension))

        # Build window matrices once for all dimensions
        win_mats = self._build_win_mats(frame_number)

        mu_frames = np.zeros((frame_number, 3))
        var_frames = np.zeros((frame_number, 3))

        for d in range(static_dimension):
            # Extract mean and variance for the current static dimension and its dynamics
            mu_frames[:, 0] = features[:, d]
            mu_frames[:, 1] = features[:, static_dimension + d]
            mu_frames[:, 2] = features[:, static_dimension * 2 + d]

            var_frames[:, 0] = covariance[:, d]
            var_frames[:, 1] = covariance[:, static_dimension + d]
            var_frames[:, 2] = covariance[:, static_dimension * 2 + d]

            # Enforce boundary conditions by setting very high variance,
            # effectively ignoring the delta/acc constraints at the edges.
            var_frames[0, 1:] = 1.0e12
            var_frames[-1, 1:] = 1.0e12

            # Avoid division by zero for frames with zero or negative variance
            var_frames[var_frames <= 0] = 1.0e-12

            # Convert means and variances to natural parameters of the Gaussian
            b_frames = mu_frames / var_frames
            tau_frames = 1.0 / var_frames

            # Construct the system of equations P * c = b
            b, P = self._build_poe(b_frames, tau_frames, win_mats)

            # Solve the linear system to find the optimal static trajectory 'c'
            try:
                mean_traj = np.linalg.solve(P, b)
            except np.linalg.LinAlgError:
                logger.warning(f"Singular precision matrix for dimension {d}. Using pseudo-inverse.")
                mean_traj = np.linalg.pinv(P) @ b

            gen_parameter[:, d] = mean_traj

        return gen_parameter