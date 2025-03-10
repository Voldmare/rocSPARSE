/*! \file */
/* ************************************************************************
 * Copyright (c) 2021-2022 Advanced Micro Devices, Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * ************************************************************************ */

#pragma once
#ifndef ROCSPARSE_BELLMM_HPP
#define ROCSPARSE_BELLMM_HPP

#include "handle.h"

typedef enum rocsparse_bellmm_alg_
{
    rocsparse_bellmm_alg_default = 0,
} rocsparse_bellmm_alg;

template <typename T, typename I = rocsparse_int>
rocsparse_status rocsparse_bellmm_template_buffer_size(rocsparse_handle          handle,
                                                       rocsparse_operation       trans_A,
                                                       rocsparse_operation       trans_B,
                                                       rocsparse_order           order_B,
                                                       rocsparse_order           order_C,
                                                       rocsparse_direction       dir_A,
                                                       I                         mb,
                                                       I                         n,
                                                       I                         kb,
                                                       I                         bell_cols,
                                                       I                         bell_block_dim,
                                                       const T*                  alpha,
                                                       const rocsparse_mat_descr descr,
                                                       const I*                  bell_col_ind,
                                                       const T*                  bell_val,
                                                       const T*                  B,
                                                       I                         ldb,
                                                       const T*                  beta,
                                                       T*                        C,
                                                       I                         ldc,
                                                       size_t*                   buffer_size);

template <typename T, typename I = rocsparse_int>
rocsparse_status rocsparse_bellmm_template_preprocess(rocsparse_handle          handle,
                                                      rocsparse_operation       trans_A,
                                                      rocsparse_operation       trans_B,
                                                      rocsparse_order           order_B,
                                                      rocsparse_order           order_C,
                                                      rocsparse_direction       dir_A,
                                                      I                         mb,
                                                      I                         n,
                                                      I                         kb,
                                                      I                         bell_cols,
                                                      I                         bell_block_dim,
                                                      const T*                  alpha,
                                                      const rocsparse_mat_descr descr,
                                                      const I*                  bell_col_ind,
                                                      const T*                  bell_val,
                                                      const T*                  B,
                                                      I                         ldb,
                                                      const T*                  beta,
                                                      T*                        C,
                                                      I                         ldc,
                                                      void*                     temp_buffer);

template <typename T, typename I = rocsparse_int>
rocsparse_status rocsparse_bellmm_template(rocsparse_handle          handle,
                                           rocsparse_operation       trans_A,
                                           rocsparse_operation       trans_B,
                                           rocsparse_order           order_B,
                                           rocsparse_order           order_C,
                                           rocsparse_direction       dir_A,
                                           I                         mb,
                                           I                         n,
                                           I                         kb,
                                           I                         bell_cols,
                                           I                         bell_block_dim,
                                           I                         batch_count_A,
                                           I                         batch_stride_A,
                                           const T*                  alpha,
                                           const rocsparse_mat_descr descr,
                                           const I*                  bell_col_ind,
                                           const T*                  bell_val,
                                           const T*                  B,
                                           I                         ldb,
                                           I                         batch_count_B,
                                           I                         batch_stride_B,
                                           const T*                  beta,
                                           T*                        C,
                                           I                         ldc,
                                           I                         batch_count_C,
                                           I                         batch_stride_C,
                                           void*                     temp_buffer);

#endif // ROCSPARSE_BELLMM_HPP
