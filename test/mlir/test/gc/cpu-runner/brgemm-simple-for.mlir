// RUN: gc-opt %s --early-dispatch-microkernel --convert-microkernel-to-dnnl-func --cse --microkernel-invariant-code-motion --convert-linalg-to-loops --convert-scf-to-cf --expand-strided-metadata --lower-affine -finalize-memref-to-llvm --convert-cpuruntime-to-llvm --convert-func-to-llvm --convert-arith-to-llvm --convert-cf-to-llvm --convert-complex-to-llvm --canonicalize --cse --reconcile-unrealized-casts --symbol-dce | gc-cpu-runner -e main -entry-point-result=void

#map = affine_map<(d0, d1) -> (d0, d1)>
module {
  func.func @simple_brgemm() {
    %c0_index = arith.constant 0 : index
    %c1_index = arith.constant 1 : index
    %c4_index = arith.constant 4 : index
    %c8_index = arith.constant 8 : index
    %c32_index = arith.constant 32 : index
    %c0_i64 = arith.constant 0 : i64
    %c16_i64 = arith.constant 16 : i64
    %cst0f = arith.constant 0.000000e+00 : f32
    %cstn64f = arith.constant -64.000000e+00 : f32
    %cst1f = arith.constant 1.000000e+00 : f32
    %cst2f = arith.constant 2.000000e+00 : f32
    %cst3f = arith.constant 3.000000e+00 : f32
    %alloc = memref.alloc() {alignment = 64 : i64} : memref<4x16x32x32xf32>
    linalg.fill ins(%cst1f : f32) outs(%alloc : memref<4x16x32x32xf32>)
    %alloc_0 = memref.alloc() {alignment = 64 : i64} : memref<8x16x32x32xf32>
    linalg.fill ins(%cst2f : f32) outs(%alloc_0 : memref<8x16x32x32xf32>)
    %alloc_1 = memref.alloc() {alignment = 64 : i64} : memref<4x8x32x32xf32>
    linalg.fill ins(%cst3f : f32) outs(%alloc_1 : memref<4x8x32x32xf32>)
    %alloc_2 = memref.alloc() {alignment = 64 : i64} : memref<4x8x32x32xf32>
    linalg.fill ins(%cst0f : f32) outs(%alloc_2 : memref<4x8x32x32xf32>)
    scf.for %arg0 = %c0_index to %c4_index step %c1_index {
      scf.for %arg1 = %c0_index to %c8_index step %c1_index {
        %alloc_3 = memref.alloc() {alignment = 64 : i64} : memref<32x32xf32>
        %arg0i = arith.index_castui %arg0 : index to i64
        %arg1i = arith.index_castui %arg1 : index to i64
        %argmulti = arith.muli %arg0i, %arg1i : i64
        %v = arith.uitofp %argmulti : i64 to f32
        %v1 = arith.mulf %v, %cstn64f : f32
        linalg.fill ins(%v1 : f32) outs(%alloc_3 : memref<32x32xf32>)
        %subview = memref.subview %alloc[%arg0, 0, 0, 0] [1, 16, 32, 32] [1, 1, 1, 1] : memref<4x16x32x32xf32> to memref<16x32x32xf32, strided<[1024, 32, 1], offset: ?>>
        %subview_4 = memref.subview %alloc_0[%arg1, 0, 0, 0] [1, 16, 32, 32] [1, 1, 1, 1] : memref<8x16x32x32xf32> to memref<16x32x32xf32, strided<[1024, 32, 1], offset: ?>>
        %0 = microkernel.brgemm.dispatch [32, 32, 32, 32, 32, 32, 1024, 1024] flags(stride) data_type(f32, f32) 
        microkernel.brgemm.prologue(%0) : (i64) -> ()
        microkernel.brgemm.execute(%0, %subview, %subview_4, %alloc_3, %c16_i64, %c0_i64) : (i64, memref<16x32x32xf32, strided<[1024, 32, 1], offset: ?>>, memref<16x32x32xf32, strided<[1024, 32, 1], offset: ?>>, memref<32x32xf32>, i64, i64) -> ()
        microkernel.brgemm.epilogue(%0) : (i64) -> ()
        %subview_5 = memref.subview %alloc_1[%arg0, %arg1, 0, 0] [1, 1, 32, 32] [1, 1, 1, 1] : memref<4x8x32x32xf32> to memref<32x32xf32, strided<[32, 1], offset: ?>>
        linalg.generic {indexing_maps = [#map, #map, #map], iterator_types = ["parallel", "parallel"]} ins(%alloc_3, %subview_5 : memref<32x32xf32>, memref<32x32xf32, strided<[32, 1], offset: ?>>) outs(%alloc_3 : memref<32x32xf32>) {
        ^bb0(%in: f32, %in_7: f32, %out: f32):
          %1 = arith.addf %in, %in_7 : f32
          linalg.yield %1 : f32
        }
        %subview_6 = memref.subview %alloc_2[%arg0, %arg1, 0, 0] [1, 1, 32, 32] [1, 1, 1, 1] : memref<4x8x32x32xf32> to memref<32x32xf32, strided<[32, 1], offset: ?>>
        linalg.generic {indexing_maps = [#map, #map], iterator_types = ["parallel", "parallel"]} ins(%alloc_3 : memref<32x32xf32>) outs(%subview_6 : memref<32x32xf32, strided<[32, 1], offset: ?>>) {
        ^bb0(%in: f32, %out: f32):
          %1 = arith.maximumf %in, %cst0f : f32
          linalg.yield %1 : f32
        }
        memref.dealloc %alloc_3 : memref<32x32xf32>
      }
    }
    scf.for %arg0 = %c0_index to %c4_index step %c1_index {
      scf.for %arg1 = %c0_index to %c8_index step %c1_index {
        scf.for %arg2 = %c0_index to %c32_index step %c1_index {
          scf.for %arg3 = %c0_index to %c32_index step %c1_index {
            %elem = memref.load %alloc_2[%arg0, %arg1, %arg2, %arg3] : memref<4x8x32x32xf32>
            cpuruntime.printf "%f, " %elem : f32 
          }
          cpuruntime.printf "\n" 
        }
	cpuruntime.printf "==================================\n" 
      }
    }
    return
  }

  func.func @main() {
    call @simple_brgemm() : ()->()
    cpuruntime.printf "BRGEMM DONE\n"
    return
  }

  // CHECK: 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000,
  // CHECK: ==================================
  // CHECK: 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000,
  // CHECK: ==================================
  // CHECK: 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000,
  // CHECK: ==================================
  // CHECK: 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000,
  // CHECK: ==================================
  // CHECK: 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000,
  // CHECK: ==================================
  // CHECK: 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000,
  // CHECK: ==================================
  // CHECK: 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000,
  // CHECK: ==================================
  // CHECK: 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000,
  // CHECK: ==================================
  // CHECK: 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000,
  // CHECK: ==================================
  // CHECK: 963.000000, 963.000000, 963.000000, 963.000000, 963.000000, 963.000000, 963.000000, 963.000000, 963.000000, 963.000000, 963.000000, 963.000000, 963.000000, 963.000000, 963.000000, 963.000000, 963.000000, 963.000000, 963.000000, 963.000000, 963.000000, 963.000000, 963.000000, 963.000000, 963.000000, 963.000000, 963.000000, 963.000000, 963.000000, 963.000000, 963.000000, 963.000000,
  // CHECK: ==================================
  // CHECK: 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000,
  // CHECK: ==================================
  // CHECK: 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000,
  // CHECK: ==================================
  // CHECK: 707.000000, 707.000000, 707.000000, 707.000000, 707.000000, 707.000000, 707.000000, 707.000000, 707.000000, 707.000000, 707.000000, 707.000000, 707.000000, 707.000000, 707.000000, 707.000000, 707.000000, 707.000000, 707.000000, 707.000000, 707.000000, 707.000000, 707.000000, 707.000000, 707.000000, 707.000000, 707.000000, 707.000000, 707.000000, 707.000000, 707.000000, 707.000000,
  // CHECK: ==================================
  // CHECK: 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000,
  // CHECK: ==================================
  // CHECK: 579.000000, 579.000000, 579.000000, 579.000000, 579.000000, 579.000000, 579.000000, 579.000000, 579.000000, 579.000000, 579.000000, 579.000000, 579.000000, 579.000000, 579.000000, 579.000000, 579.000000, 579.000000, 579.000000, 579.000000, 579.000000, 579.000000, 579.000000, 579.000000, 579.000000, 579.000000, 579.000000, 579.000000, 579.000000, 579.000000, 579.000000, 579.000000,
  // CHECK: ==================================
  // CHECK: 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000,
  // CHECK: ==================================
  // CHECK: 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000, 899.000000,
  // CHECK: ==================================
  // CHECK: 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000, 771.000000,
  // CHECK: ==================================
  // CHECK: 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000,
  // CHECK: ==================================
  // CHECK: 515.000000, 515.000000, 515.000000, 515.000000, 515.000000, 515.000000, 515.000000, 515.000000, 515.000000, 515.000000, 515.000000, 515.000000, 515.000000, 515.000000, 515.000000, 515.000000, 515.000000, 515.000000, 515.000000, 515.000000, 515.000000, 515.000000, 515.000000, 515.000000, 515.000000, 515.000000, 515.000000, 515.000000, 515.000000, 515.000000, 515.000000, 515.000000, 
  // CHECK: ==================================
  // CHECK: 387.000000, 387.000000, 387.000000, 387.000000, 387.000000, 387.000000, 387.000000, 387.000000, 387.000000, 387.000000, 387.000000, 387.000000, 387.000000, 387.000000, 387.000000, 387.000000, 387.000000, 387.000000, 387.000000, 387.000000, 387.000000, 387.000000, 387.000000, 387.000000, 387.000000, 387.000000, 387.000000, 387.000000, 387.000000, 387.000000, 387.000000, 387.000000,
  // CHECK: ==================================
  // CHECK: 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000,
  // CHECK: ==================================
  // CHECK: 131.000000, 131.000000, 131.000000, 131.000000, 131.000000, 131.000000, 131.000000, 131.000000, 131.000000, 131.000000, 131.000000, 131.000000, 131.000000, 131.000000, 131.000000, 131.000000, 131.000000, 131.000000, 131.000000, 131.000000, 131.000000, 131.000000, 131.000000, 131.000000, 131.000000, 131.000000, 131.000000, 131.000000, 131.000000, 131.000000, 131.000000, 131.000000,
  // CHECK: ==================================
  // CHECK: 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000, 1027.000000,
  // CHECK: ==================================
  // CHECK: 835.000000, 835.000000, 835.000000, 835.000000, 835.000000, 835.000000, 835.000000, 835.000000, 835.000000, 835.000000, 835.000000, 835.000000, 835.000000, 835.000000, 835.000000, 835.000000, 835.000000, 835.000000, 835.000000, 835.000000, 835.000000, 835.000000, 835.000000, 835.000000, 835.000000, 835.000000, 835.000000, 835.000000, 835.000000, 835.000000, 835.000000, 835.000000,
  // CHECK: ==================================
  // CHECK: 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000, 643.000000,
  // CHECK: ==================================
  // CHECK: 451.000000, 451.000000, 451.000000, 451.000000, 451.000000, 451.000000, 451.000000, 451.000000, 451.000000, 451.000000, 451.000000, 451.000000, 451.000000, 451.000000, 451.000000, 451.000000, 451.000000, 451.000000, 451.000000, 451.000000, 451.000000, 451.000000, 451.000000, 451.000000, 451.000000, 451.000000, 451.000000, 451.000000, 451.000000, 451.000000, 451.000000, 451.000000,
  // CHECK: ==================================
  // CHECK: 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000, 259.000000,
  // CHECK: ==================================
  // CHECK: 67.000000, 67.000000, 67.000000, 67.000000, 67.000000, 67.000000, 67.000000, 67.000000, 67.000000, 67.000000, 67.000000, 67.000000, 67.000000, 67.000000, 67.000000, 67.000000, 67.000000, 67.000000, 67.000000, 67.000000, 67.000000, 67.000000, 67.000000, 67.000000, 67.000000, 67.000000, 67.000000, 67.000000, 67.000000, 67.000000, 67.000000, 67.000000,
  // CHECK: ==================================
  // CHECK: 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  // CHECK: ==================================
  // CHECK: 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
  // CHECK: ==================================
  // CHECK: BRGEMM DONE
}