/*! \file */
/* ************************************************************************
 * Copyright (c) 2019-2022 Advanced Micro Devices, Inc.
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

#include "testing.hpp"

#include "auto_testing_bad_arg.hpp"

template <typename T>
void testing_csr2ell_bad_arg(const Arguments& arg)
{
    static const size_t safe_size = 100;

    // Create rocsparse handle
    rocsparse_local_handle local_handle;

    // Create matrix descriptor for CSR matrix
    rocsparse_local_mat_descr local_csr_descr;

    // Create matrix descriptor for ELL matrix
    rocsparse_local_mat_descr local_ell_descr;

    rocsparse_handle          handle        = local_handle;
    rocsparse_int             m             = safe_size;
    const rocsparse_mat_descr csr_descr     = local_csr_descr;
    const T*                  csr_val       = (const T*)0x4;
    const rocsparse_int*      csr_row_ptr   = (const rocsparse_int*)0x4;
    const rocsparse_int*      csr_col_ind   = (const rocsparse_int*)0x4;
    const rocsparse_mat_descr ell_descr     = local_ell_descr;
    rocsparse_int*            ell_width_ptr = (rocsparse_int*)0x4;
    rocsparse_int             ell_width     = safe_size;
    T*                        ell_val       = (T*)0x4;
    rocsparse_int*            ell_col_ind   = (rocsparse_int*)0x4;

#define PARAMS_WIDTH handle, m, csr_descr, csr_row_ptr, ell_descr, ell_width_ptr
#define PARAMS                                                                              \
    handle, m, csr_descr, csr_val, csr_row_ptr, csr_col_ind, ell_descr, ell_width, ell_val, \
        ell_col_ind
    auto_testing_bad_arg(rocsparse_csr2ell_width, PARAMS_WIDTH);
    auto_testing_bad_arg(rocsparse_csr2ell<T>, PARAMS);
#undef PARAMS
#undef PARAMS_WIDTH
}

template <typename T>
void testing_csr2ell(const Arguments& arg)
{
    rocsparse_matrix_factory<T> matrix_factory(arg);
    rocsparse_int               M     = arg.M;
    rocsparse_int               N     = arg.N;
    rocsparse_index_base        baseA = arg.baseA;
    rocsparse_index_base        baseB = arg.baseB;

    // Create rocsparse handle
    rocsparse_local_handle handle;

    // Create matrix descriptor for CSR matrix
    rocsparse_local_mat_descr descrA;

    // Create matrix descriptor for ELL matrix
    rocsparse_local_mat_descr descrB;

    // Set matrix index base
    CHECK_ROCSPARSE_ERROR(rocsparse_set_mat_index_base(descrA, baseA));
    CHECK_ROCSPARSE_ERROR(rocsparse_set_mat_index_base(descrB, baseB));

    // Argument sanity check before allocating invalid memory
    if(M <= 0 || N <= 0)
    {
        static const size_t safe_size = 100;
        size_t              ptr_size  = std::max(safe_size, static_cast<size_t>(M + 1));

        // Allocate memory on device
        device_vector<rocsparse_int> dcsr_row_ptr(ptr_size);
        device_vector<rocsparse_int> dcsr_col_ind(safe_size);
        device_vector<T>             dcsr_val(safe_size);
        device_vector<rocsparse_int> dell_col_ind(safe_size);
        device_vector<T>             dell_val(safe_size);

        if(!dcsr_row_ptr || !dcsr_col_ind || !dcsr_val || !dell_col_ind || !dell_val)
        {
            CHECK_HIP_ERROR(hipErrorOutOfMemory);
            return;
        }

        // Need to initialize csr_row_ptr with 0
        CHECK_HIP_ERROR(hipMemset(dcsr_row_ptr, 0, sizeof(rocsparse_int) * ptr_size));

        rocsparse_int ell_width;

        EXPECT_ROCSPARSE_STATUS(
            rocsparse_csr2ell_width(handle, M, descrA, dcsr_row_ptr, descrB, &ell_width),
            (M < 0) ? rocsparse_status_invalid_size : rocsparse_status_success);
        EXPECT_ROCSPARSE_STATUS(rocsparse_csr2ell<T>(handle,
                                                     M,
                                                     descrA,
                                                     dcsr_val,
                                                     dcsr_row_ptr,
                                                     dcsr_col_ind,
                                                     descrB,
                                                     ell_width,
                                                     dell_val,
                                                     dell_col_ind),
                                (M < 0) ? rocsparse_status_invalid_size : rocsparse_status_success);

        return;
    }

    // Allocate host memory for matrix
    host_vector<rocsparse_int> hcsr_row_ptr;
    host_vector<rocsparse_int> hcsr_col_ind;
    host_vector<T>             hcsr_val;
    host_vector<rocsparse_int> hell_col_ind;
    host_vector<T>             hell_val;
    host_vector<rocsparse_int> hell_col_ind_gold;
    host_vector<T>             hell_val_gold;

    // Sample matrix
    rocsparse_int nnz;
    matrix_factory.init_csr(hcsr_row_ptr, hcsr_col_ind, hcsr_val, M, N, nnz, baseA);

    // Allocate device memory
    device_vector<rocsparse_int> dcsr_row_ptr(M + 1);
    device_vector<rocsparse_int> dcsr_col_ind(nnz);
    device_vector<T>             dcsr_val(nnz);

    if(!dcsr_row_ptr || !dcsr_col_ind || !dcsr_val)
    {
        CHECK_HIP_ERROR(hipErrorOutOfMemory);
        return;
    }

    // Copy data from CPU to device
    CHECK_HIP_ERROR(hipMemcpy(
        dcsr_row_ptr, hcsr_row_ptr, sizeof(rocsparse_int) * (M + 1), hipMemcpyHostToDevice));
    CHECK_HIP_ERROR(
        hipMemcpy(dcsr_col_ind, hcsr_col_ind, sizeof(rocsparse_int) * nnz, hipMemcpyHostToDevice));
    CHECK_HIP_ERROR(hipMemcpy(dcsr_val, hcsr_val, sizeof(T) * nnz, hipMemcpyHostToDevice));

    if(arg.unit_check)
    {
        // Obtain ELL width
        rocsparse_int ell_width;
        CHECK_ROCSPARSE_ERROR(
            rocsparse_csr2ell_width(handle, M, descrA, dcsr_row_ptr, descrB, &ell_width));

        // Allocate device memory
        rocsparse_int ell_nnz = ell_width * M;

        device_vector<rocsparse_int> dell_col_ind(ell_nnz);
        device_vector<T>             dell_val(ell_nnz);

        if(!dell_col_ind || !dell_val)
        {
            CHECK_HIP_ERROR(hipErrorOutOfMemory);
            return;
        }

        // Perform ELL conversion
        CHECK_ROCSPARSE_ERROR(rocsparse_csr2ell<T>(handle,
                                                   M,
                                                   descrA,
                                                   dcsr_val,
                                                   dcsr_row_ptr,
                                                   dcsr_col_ind,
                                                   descrB,
                                                   ell_width,
                                                   dell_val,
                                                   dell_col_ind));

        // Copy output to host
        hell_col_ind.resize(ell_nnz);
        hell_val.resize(ell_nnz);

        CHECK_HIP_ERROR(hipMemcpy(
            hell_col_ind, dell_col_ind, sizeof(rocsparse_int) * ell_nnz, hipMemcpyDeviceToHost));
        CHECK_HIP_ERROR(hipMemcpy(hell_val, dell_val, sizeof(T) * ell_nnz, hipMemcpyDeviceToHost));

        // CPU csr2ell
        rocsparse_int ell_width_gold;
        host_csr_to_ell(M,
                        hcsr_row_ptr,
                        hcsr_col_ind,
                        hcsr_val,
                        hell_col_ind_gold,
                        hell_val_gold,
                        ell_width_gold,
                        baseA,
                        baseB);

        unit_check_scalar(ell_width_gold, ell_width);
        hell_col_ind_gold.unit_check(hell_col_ind);
        hell_val_gold.unit_check(hell_val);
    }

    if(arg.timing)
    {
        int number_cold_calls = 2;
        int number_hot_calls  = arg.iters;

        rocsparse_int ell_width;
        rocsparse_int ell_nnz;

        // Warm up
        for(int iter = 0; iter < number_cold_calls; ++iter)
        {
            CHECK_ROCSPARSE_ERROR(
                rocsparse_csr2ell_width(handle, M, descrA, dcsr_row_ptr, descrB, &ell_width));

            ell_nnz = ell_width * M;

            device_vector<rocsparse_int> dell_col_ind(ell_nnz);
            device_vector<T>             dell_val(ell_nnz);

            if(!dell_col_ind || !dell_val)
            {
                CHECK_HIP_ERROR(hipErrorOutOfMemory);
                return;
            }

            CHECK_ROCSPARSE_ERROR(rocsparse_csr2ell<T>(handle,
                                                       M,
                                                       descrA,
                                                       dcsr_val,
                                                       dcsr_row_ptr,
                                                       dcsr_col_ind,
                                                       descrB,
                                                       ell_width,
                                                       dell_val,
                                                       dell_col_ind));
        }

        double gpu_time_used = get_time_us();

        // Performance run
        for(int iter = 0; iter < number_hot_calls; ++iter)
        {
            CHECK_ROCSPARSE_ERROR(
                rocsparse_csr2ell_width(handle, M, descrA, dcsr_row_ptr, descrB, &ell_width));

            ell_nnz = ell_width * M;

            device_vector<rocsparse_int> dell_col_ind(ell_nnz);
            device_vector<T>             dell_val(ell_nnz);

            if(!dell_col_ind || !dell_val)
            {
                CHECK_HIP_ERROR(hipErrorOutOfMemory);
                return;
            }

            CHECK_ROCSPARSE_ERROR(rocsparse_csr2ell<T>(handle,
                                                       M,
                                                       descrA,
                                                       dcsr_val,
                                                       dcsr_row_ptr,
                                                       dcsr_col_ind,
                                                       descrB,
                                                       ell_width,
                                                       dell_val,
                                                       dell_col_ind));
        }

        gpu_time_used = (get_time_us() - gpu_time_used) / number_hot_calls;

        double gbyte_count = csr2ell_gbyte_count<T>(M, nnz, ell_nnz);
        double gpu_gbyte   = get_gpu_gbyte(gpu_time_used, gbyte_count);

        display_timing_info("M",
                            M,
                            "N",
                            N,
                            "ELL width",
                            ell_width,
                            "ELL nnz",
                            ell_nnz,
                            s_timing_info_bandwidth,
                            gpu_gbyte,
                            s_timing_info_time,
                            get_gpu_time_msec(gpu_time_used));
    }
}

#define INSTANTIATE(TYPE)                                              \
    template void testing_csr2ell_bad_arg<TYPE>(const Arguments& arg); \
    template void testing_csr2ell<TYPE>(const Arguments& arg)
INSTANTIATE(float);
INSTANTIATE(double);
INSTANTIATE(rocsparse_float_complex);
INSTANTIATE(rocsparse_double_complex);
