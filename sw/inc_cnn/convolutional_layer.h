#pragma once
// =============================================================================
//  Program : activation_function.h
//  Author  : Chang-Jyun Liao
//  Date    : July/14/2024
// -----------------------------------------------------------------------------
//  Description:
//      This file defines the convolutional layer for the CNN models.
// -----------------------------------------------------------------------------
//  Revision information:
//  Dec/3/2024, by Chang-Jyun Liao:
//      Re-write the padding and forwarding function to increase performance.
// -----------------------------------------------------------------------------
//  License information:
//
//  This software is released under the BSD-3-Clause Licence,
//  see https://opensource.org/licenses/BSD-3-Clause for details.
//  In the following license statements, "software" refers to the
//  "source code" of the complete hardware/software system.
//
//  Copyright 2024,
//                    Embedded Intelligent Systems Lab (EISL)
//                    Deparment of Computer Science
//                    National Yang Ming Chiao Tung University
//                    Hsinchu, Taiwan.
//
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  1. Redistributions of source code must retain the above copyright notice,
//     this list of conditions and the following disclaimer.
//
//  2. Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other materials provided with the distribution.
//
//  3. Neither the name of the copyright holder nor the names of its contributors
//     may be used to endorse or promote products derived from this software
//     without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
// =============================================================================


#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "config.h"
#include "layer.h"
#include "list.h"
#include "util.h"
#include "activation_function.h"

enum padding{
    valid,
    same
};

typedef struct _convolutional_layer
{
    layer_base base;
    index3d in_;
    index3d in_padded_;
    index3d out_;
    index3d weight_;
    index3d padding_;
    enum padding pad_type_;
    uint32_t w_stride_;
    uint32_t h_stride_;
    uint8_t has_bias_;

    uint32_t padding_done_flag;
    uint32_t padding_mask;
} convolutional_layer;

convolutional_layer * get_convolutional_layer_entry(struct list_node *ptr)
{
    return list_entry(ptr, convolutional_layer, base.list);
}

static uint32_t in_length(uint32_t in_length, uint32_t padding_size, enum padding pad_type)
{
    return pad_type == same ? in_length + 2 * padding_size : in_length;
}

static uint32_t conv_out_length(uint32_t in_length, uint32_t window_size, uint32_t padding_size, uint32_t stride, enum padding pad_type)
{
    return pad_type == same ?
               (int)(((float_t)in_length + 2 * padding_size - window_size) / stride) + 1 :
               (uint32_t) no_math_ceil((float_t)(in_length - window_size + 1) / stride);
}

static uint32_t conv_out_dim(uint32_t in_width, uint32_t in_height, uint32_t window_width,  uint32_t window_height, uint32_t w_padding, uint32_t h_padding, uint32_t w_stride, uint32_t h_stride, enum padding pad_type)
{
    return conv_out_length(in_width, window_width, w_padding, w_stride, pad_type) * conv_out_length(in_height, window_height, h_padding, h_stride, pad_type);
}

void conv_copy_and_pad_input(convolutional_layer *entry, input_struct *input)
{
    if (entry->pad_type_ == same)
    {
        index3d in_ = entry->in_;
        index3d in_padded_ = entry->in_padded_;
        index3d padding_ = entry->padding_;

        uint32_t c = 0;
        uint32_t y = 0;

        float_t *in = input->in_ptr_;
        float_t *dst = entry->base.padded_ptr;
        uint32_t total_size = in_.depth_ * in_.height_;

        for (uint32_t i = 0; i < total_size; i++)
        {
            float_t *pimg = &dst[get_index(&in_padded_, padding_.width_, padding_.height_ + y, c)];
            const float_t *pin = &in[get_index(&in_, 0, y, c)];

            for (uint32_t x = 0; x < in_.width_; x++)
            {
                pimg[x] = pin[x];
            }
            
            y++;
            if (y == in_.height_)
            {
                y = 0;
                c++;
            }
        }
    }
}

void conv_3d(uint32_t o, convolutional_layer *entry, float_t *pa)
{
#ifdef USE_DSA_ACCELERATOR
    // ============================================================
    // DSA Conv Acceleration using FMA IP (latency = 17 cycles)
    // FMA computes: A * B + C
    // Software provides C value for accumulation control
    // Address: 0x0C = A, 0x10 = B, 0x14 write = C (trigger), 0x14 read = result
    // ============================================================
    float_t *W = entry->base._W;
    float_t *in = entry->base.padded_ptr;
    index3d in_ = entry->in_;
    index3d out_ = entry->out_;
    index3d in_padded_ = entry->in_padded_;
    index3d weight_ = entry->weight_;
    uint32_t h_stride_ = entry->h_stride_;
    uint32_t w_stride_ = entry->w_stride_;
    const uint32_t const1 = in_padded_.width_ - weight_.width_;
    const uint32_t const2 = h_stride_ * in_padded_.width_ - out_.width_ * w_stride_;

    for (uint32_t inc = 0; inc < in_.depth_; inc++) {
        const float_t *pw = &W[get_index(&weight_, 0, 0, in_.depth_ * o + inc)];

        float_t *ppi = &in[get_index(&in_padded_, 0, 0, inc)];
        uint32_t idx = 0;
        const uint32_t inner_loop_iter = weight_.height_ * weight_.width_;
        
        for (uint32_t y = 0; y < out_.height_; y++) {
            for (uint32_t x = 0; x < out_.width_; x++) {
                const float_t *ppw = pw;
                float_t acc = 0.0f;  // Software accumulator
                uint32_t wx = 0, widx = 0;
                
                // Inner product using FMA: result = A * B + C
                for (uint32_t wyx = 0; wyx < inner_loop_iter; wyx++) {
                    *((volatile float *)0xC400000C) = *ppw++;
                    *((volatile float *)0xC4000010) = ppi[widx];
                    *((volatile float *)0xC4000014) = acc;
                    
                    for (volatile int delay = 0; delay < 1; delay++);
                    
                    acc = *((volatile float *)0xC4000014);
                    
                    wx++;
                    widx++;
                    if (wx == weight_.width_) {
                        wx = 0;
                        widx += const1;
                    }
                }
                
                pa[idx++] += acc;
                ppi += w_stride_;
            }
            ppi += const2;
        }
    }
    
#else
    // DEBUG: 確認軟體路徑被執行
    static int first_call_sw = 1;
    if (first_call_sw) {
        printf("[SW] Using software implementation for conv_3d\n");
        first_call_sw = 0;
    }
    
    // 原始軟體實現
    float_t *W = entry->base._W;
    float_t *in = entry->base.padded_ptr;
    index3d in_ = entry->in_;
    index3d out_ = entry->out_;
    index3d in_padded_ = entry->in_padded_;
    index3d weight_ = entry->weight_;
    uint32_t h_stride_ = entry->h_stride_;
    uint32_t w_stride_ = entry->w_stride_;
    const uint32_t const1 = in_padded_.width_ - weight_.width_;
    const uint32_t const2 = h_stride_ * in_padded_.width_ - out_.width_ * w_stride_;

    for (uint32_t inc = 0; inc < in_.depth_; inc++) {
        const float_t *pw = &W[get_index(&weight_, 0, 0, in_.depth_ * o + inc)];

        float_t * ppi = &in[get_index(&in_padded_, 0, 0, inc)];
        uint32_t idx = 0;
        const uint32_t inner_loop_iter = weight_.height_ * weight_.width_;
        for (uint32_t y = 0; y < out_.height_; y++) {
            for (uint32_t x = 0; x < out_.width_; x++) {
                const float_t * ppw = pw;
                float_t sum = (float_t)0;
                uint32_t wx = 0, widx = 0;
                for (uint32_t wyx = 0; wyx < inner_loop_iter; wyx++) {
                    sum += *ppw++ * ppi[widx];
                    wx++;
                    widx++;
                    if (wx == weight_.width_)
                    {
                        wx = 0;
                        widx += const1;
                    }
                }
                pa[idx++] += sum;
                ppi += w_stride_;
            }
            ppi += const2;
        }
    }
#endif
}

void convolutional_layer_forward_propagation(struct list_node *ptr, input_struct *input)
{
    convolutional_layer *entry = get_convolutional_layer_entry(ptr);
    
    if (input->in_size_ != entry->base.in_size_)
    {
        printf("Error input size not match %u/%u\n", input->in_size_, entry->base.in_size_);
        exit(-1);
    }
    
#ifdef USE_DSA_ACCELERATOR
    // Hardware profiling: Mark Conv layer start (addr 0x34)
    *((volatile uint32_t *)0xC4000034) = 0x1;  // CONV_START flag
    
    // Mark copy+pad start (addr 0x38)
    *((volatile uint32_t *)0xC4000038) = 0x1;
#endif
    
    conv_copy_and_pad_input(entry, input);
    
#ifdef USE_DSA_ACCELERATOR
    // Mark copy+pad end
    *((volatile uint32_t *)0xC4000038) = 0x0;
    
    // Mark compute start (addr 0x3C)
    *((volatile uint32_t *)0xC400003C) = 0x1;
#endif

    float_t *a = entry->base.a_ptr_;
    float_t *b = entry->base._b;
    float_t *out = entry->base.out_ptr_;
    input->in_ptr_ = out;
    input->in_size_ = entry->base.out_size_;
    index3d out_ = entry->out_;
    uint32_t total_size = out_.depth_;
    uint32_t out_dim = out_.height_*out_.width_;

#if defined(USE_DSA_ACCELERATOR) && defined(USE_CONV3D_BUFFERED)
    // ============================================================
    // Conv3D Buffered Mode with Weight Preloading
    // Conv1 (1×5×5×3 = 75 weights): 0xC410_0000/0004/0008
    // Conv2 (3×5×5×12 = 900 weights): 0xC410_0010/0014/0018
    // ============================================================
    float_t *W = entry->base._W;
    float_t *in = entry->base.padded_ptr;
    index3d in_ = entry->in_;
    index3d weight_ = entry->weight_;
    
    uint32_t out_size = out_dim * total_size;
    uint32_t weight_size = weight_.width_ * weight_.height_ * weight_.depth_;
    uint32_t input_image_size = in_.width_ * in_.height_ * in_.depth_;  // Use original size, not padded!
    
    // Pointer to input image (from padded buffer, but read original size)
    float_t *ppi = &in[get_index(&in_, 0, 0, 0)];
    float_t *pw = &W[get_index(&weight_, 0, 0, 0)];
    
    // Static flags to track if weights are preloaded for each conv layer
    static int conv1_preloaded = 0;  // Conv1: 1×5×5×3 = 75
    static int conv2_preloaded = 0;  // Conv2: 3×5×5×12 = 900
    
    // Determine layer type based on weight size
    int is_conv1 = (weight_size == 75);   // 1*5*5*3
    int is_conv2 = (weight_size == 900);  // 3*5*5*12
    int is_preloaded = is_conv1 ? conv1_preloaded : (is_conv2 ? conv2_preloaded : 0);
    
    // Select addresses based on layer
    uint32_t addr_full       = is_conv1 ? 0xC4100000 : 0xC4100010;
    uint32_t addr_weight     = is_conv1 ? 0xC4100004 : 0xC4100014;
    uint32_t addr_input_only = is_conv1 ? 0xC4100008 : 0xC4100018;
    
    // Step 1: Initialize parameters (same as data_feeder.v)
    *((volatile int *)0xC4600004) = in_.width_;    // in_width (original, not padded!)
    *((volatile int *)0xC4600008) = out_.width_;   // out_width
    *((volatile int *)0xC460000C) = in_.depth_;    // in_depth
    *((volatile int *)0xC4600010) = out_.depth_;   // out_depth
    
    // Step 2: Set input image size trigger
    *((volatile int *)0xC4200000) = input_image_size;
    
    // Step 3: Set output size (for output buffer init)
    *((volatile int *)0xC4300000) = out_size;
    
    if (!is_preloaded) {
        // Full mode: load weights
        // Step 4: Set weight size trigger (full mode)
        *((volatile int *)addr_full) = weight_size;
        
        // Step 5: Load weights
        for (uint32_t i = 0; i < weight_size; i++) {
            *((volatile float *)addr_weight) = *pw++;
        }
        
        // Mark as preloaded
        if (is_conv1) conv1_preloaded = 1;
        else if (is_conv2) conv2_preloaded = 1;
    } else {
        // Input-only mode: reuse weights
        *((volatile int *)addr_input_only) = weight_size;
    }
    
    // Step 6: Load input image (always needed)
    for (uint32_t i = 0; i < input_image_size; i++) {
        *((volatile float *)0xC4200004) = *ppi++;
    }
    
    // Step 7: Trigger computation
    *((volatile int *)0xC4600000) = 1;
    
    // Step 8: Wait for completion (busy wait)
    while (*((volatile int *)0xC4600000));
    
    // Step 9: Read output with ReLU
    for (uint32_t i = 0; i < out_size; i++) {
        out[i] = *((volatile float *)0xC4300008);  // Read with ReLU
    }
    
#else
    // Non-buffered mode: compute per output channel
    for (uint32_t o = 0; o < total_size; o++)
    {
        float_t *pa = &a[get_index(&out_, 0, 0, o)];
        memset((void*)pa, 0, out_dim *sizeof(float_t));

        conv_3d(o, entry, pa);

        if (entry->has_bias_) {
            for (uint32_t index = 0; index < out_dim; index++)
                pa[index] += b[o];
        }
    }
#endif
    
#ifdef USE_DSA_ACCELERATOR
    // Mark compute end
    *((volatile uint32_t *)0xC400003C) = 0x0;
#endif

    // total_size = entry->base.out_size_;

    // for (uint32_t c = 0; c < total_size; c++)
    //     out[c] = entry->base.activate(a, c, entry->base.out_size_);
    
#ifdef USE_DSA_ACCELERATOR
    // Hardware profiling: Mark Conv layer end
    *((volatile uint32_t *)0xC4000034) = 0x0;  // CONV_END flag
#endif
    
#ifdef PRINT_LAYER
    printf("[%s] done [%f, %f, ... , %f, %f]\n", entry->base.layer_name_, out[0], out[1], out[entry->base.out_size_-2], out[entry->base.out_size_-1]);
#endif
}

layer_base * new_convolutional_layer(
                                     cnn_controller *ctrl,
                                     float_t(*activate) (float_t *, uint32_t, uint32_t),
                                     uint32_t in_width,
                                     uint32_t in_height,
                                     uint32_t window_width,
                                     uint32_t window_height,
                                     uint32_t in_channels,
                                     uint32_t out_channels,
                                     enum padding  pad_type,
                                     uint8_t  has_bias,
                                     uint32_t w_stride,
                                     uint32_t h_stride,
                                     uint32_t w_padding,
                                     uint32_t h_padding
                                    )
{
    convolutional_layer *ret = (convolutional_layer *)malloc(sizeof(convolutional_layer));

    if (pad_type == same)
        ctrl->padding_size = in_length(in_width, w_padding, pad_type) * in_length(in_height, h_padding, pad_type) * in_channels;
    else 
        ctrl->padding_size = 0;
        
    init_layer(&ret->base,
               ctrl,
               in_width*in_height*in_channels,
               conv_out_dim(in_width, in_height, window_width, window_height, w_padding, h_padding, w_stride, h_stride, pad_type) * out_channels, 
               window_width * window_height * in_channels * out_channels,
               has_bias ? out_channels : 0,
               activate
              );
#ifdef PRINT_LAYER
    static uint32_t call_time = 0;
    sprintf(ret->base.layer_name_, "conv%u", call_time++);
#endif
    ret->in_ = new_index3d(in_width, in_height, in_channels);
    ret->in_padded_ = new_index3d(in_length(in_width, w_padding, pad_type), in_length(in_height, h_padding, pad_type), in_channels);
    ret->out_ = new_index3d(conv_out_length(in_width, window_width, w_padding, w_stride, pad_type), conv_out_length(in_height, window_height, h_padding, h_stride, pad_type), out_channels);
    ret->weight_ = new_index3d(window_width, window_height, in_channels*out_channels);
    ret->padding_ = new_index3d(w_padding, h_padding, 0);
    ret->pad_type_ = pad_type;
    ret->w_stride_ = w_stride;
    ret->h_stride_ = h_stride;
    ret->has_bias_ = has_bias;

    ret->base.activate = activate;
    ret->base.forward_propagation = convolutional_layer_forward_propagation;
    // printf("insize of average pooling layer %d\n", ret->base.in_size_);
#ifdef PRINT_LAYER
    printf("conv: W [%f, %f, ... , %f, %f]\n", ret->base._W[0], ret->base._W[1], ret->base._W[window_width * window_height * in_channels * out_channels-2], ret->base._W[window_width * window_height * in_channels * out_channels-1]);
#endif
    // printf("conv: in [%f, %f, ... , %f, %f]\n", ret->base.in_ptr_[0], ret->base.in_ptr_[1], ret->base.in_ptr_[ret->base.in_size_-2], ret->base.in_ptr_[ret->base.in_size_-1]);
    // printf("conv: b  [%f, %f, ... , %f, %f]\n", ret->base._b[0], ret->base._b[1], ret->base._b[in_channels-2], ret->base._b[in_channels-1]);
    return &ret->base;
}
