public void glsl_barrier() {
    __target_switch {
        case glsl: __intrinsic_asm "barrier()";
    }
}
