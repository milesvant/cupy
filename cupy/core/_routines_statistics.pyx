from cupy.core._kernel import create_reduction_func
from cupy.core._kernel import ReductionKernel

from cupy.core cimport _routines_math as _math
from cupy.core.core cimport ndarray


cdef ndarray _ndarray_max(ndarray self, axis, out, dtype, keepdims):
    return _amax(self, axis=axis, out=out, dtype=dtype, keepdims=keepdims)


cdef ndarray _ndarray_min(ndarray self, axis, out, dtype, keepdims):
    return _amin(self, axis=axis, out=out, dtype=dtype, keepdims=keepdims)


cdef ndarray _ndarray_argmax(ndarray self, axis, out, dtype, keepdims):
    return _argmax(self, axis=axis, out=out, dtype=dtype, keepdims=keepdims)


cdef ndarray _ndarray_argmin(ndarray self, axis, out, dtype, keepdims):
    return _argmin(self, axis=axis, out=out, dtype=dtype, keepdims=keepdims)


cdef ndarray _ndarray_mean(ndarray self, axis, dtype, out, keepdims):
    return _mean(self, axis=axis, dtype=dtype, out=out, keepdims=keepdims)


cdef ndarray _ndarray_var(ndarray self, axis, dtype, out, ddof, keepdims):
    return _var(
        self, axis=axis, dtype=dtype, out=out, ddof=ddof, keepdims=keepdims)


cdef ndarray _ndarray_std(ndarray self, axis, dtype, out, ddof, keepdims):
    return _std(
        self, axis=axis, dtype=dtype, out=out, ddof=ddof, keepdims=keepdims)


cpdef ndarray _ndarray_nanmean(ndarray self, axis, dtype, out, keepdims):
    return _nanmean(self, axis=axis, dtype=dtype, out=out, keepdims=keepdims)


cdef _min_max_preamble = '''
template <typename T>
struct min_max_st{
    T value;
    int index;
    __device__ min_max_st() : index(-1) { }
    __device__ min_max_st(T v) : value(v), index(0) { }
    __device__ min_max_st(T v, int i) : value(v), index(i) { }
};

template <typename T>
inline __device__ bool is_nan(T x) {
    return x != x;
}

template <typename T>
__device__ min_max_st<T> my_min(
        const min_max_st<T>& a, const min_max_st<T>& b) {
    if (a.index == -1) return b;
    if (b.index == -1) return a;
    return min_max_st<T>(min(a.value, b.value));
}
template <typename T>
__device__ min_max_st<T> my_min_float(
        const min_max_st<T>& a, const min_max_st<T>& b) {
    if (a.index == -1) return b;
    if (b.index == -1) return a;
    if (is_nan(a.value)) return a;
    if (is_nan(b.value)) return b;
    return min_max_st<T>(min(a.value, b.value));
}
template <typename T>
__device__ min_max_st<T> my_min_complex(
        const min_max_st<T>& a, const min_max_st<T>& b) {
    if (a.index == -1) return b;
    if (b.index == -1) return a;
    if (is_nan(a.value.real())) return a;
    if (is_nan(a.value.imag())) return a;
    if (is_nan(b.value.real())) return b;
    if (is_nan(b.value.imag())) return b;
    return min_max_st<T>(min(a.value, b.value));
}

template <typename T>
__device__ min_max_st<T> my_max(
        const min_max_st<T>& a, const min_max_st<T>& b) {
    if (a.index == -1) return b;
    if (b.index == -1) return a;
    return min_max_st<T>(max(a.value, b.value));
}
template <typename T>
__device__ min_max_st<T> my_max_float(
        const min_max_st<T>& a, const min_max_st<T>& b) {
    if (a.index == -1) return b;
    if (b.index == -1) return a;
    if (is_nan(a.value)) return a;
    if (is_nan(b.value)) return b;
    return min_max_st<T>(max(a.value, b.value));
}
template <typename T>
__device__ min_max_st<T> my_max_complex(
        const min_max_st<T>& a, const min_max_st<T>& b) {
    if (a.index == -1) return b;
    if (b.index == -1) return a;
    if (is_nan(a.value.real())) return a;
    if (is_nan(a.value.imag())) return a;
    if (is_nan(b.value.real())) return b;
    if (is_nan(b.value.imag())) return b;
    return min_max_st<T>(max(a.value, b.value));
}

template <typename T>
__device__ min_max_st<T> my_argmin(
        const min_max_st<T>& a, const min_max_st<T>& b) {
    if (a.index == -1) return b;
    if (b.index == -1) return a;
    if (a.value == b.value)
        return min_max_st<T>(a.value, min(a.index, b.index));
    return (a.value <= b.value) ? a : b;
}
template <typename T>
__device__ min_max_st<T> my_argmin_float(
        const min_max_st<T>& a, const min_max_st<T>& b) {
    if (a.index == -1) return b;
    if (b.index == -1) return a;
    if (a.value == b.value)
        return min_max_st<T>(a.value, min(a.index, b.index));
    if (is_nan(a.value)) return a;
    if (is_nan(b.value)) return b;
    return (a.value <= b.value) ? a : b;
}
template <typename T>
__device__ min_max_st<T> my_argmin_complex(
        const min_max_st<T>& a, const min_max_st<T>& b) {
    if (a.index == -1) return b;
    if (b.index == -1) return a;
    if (a.value == b.value)
        return min_max_st<T>(a.value, min(a.index, b.index));
    if (is_nan(a.value.real())) return a;
    if (is_nan(a.value.imag())) return a;
    if (is_nan(b.value.real())) return b;
    if (is_nan(b.value.imag())) return b;
    return (a.value <= b.value) ? a : b;
}

template <typename T>
__device__ min_max_st<T> my_argmax(
        const min_max_st<T>& a, const min_max_st<T>& b) {
    if (a.index == -1) return b;
    if (b.index == -1) return a;
    if (a.value == b.value)
        return min_max_st<T>(a.value, min(a.index, b.index));
    return (a.value >= b.value) ? a : b;
}
template <typename T>
__device__ min_max_st<T> my_argmax_float(
        const min_max_st<T>& a, const min_max_st<T>& b) {
    if (a.index == -1) return b;
    if (b.index == -1) return a;
    if (a.value == b.value)
        return min_max_st<T>(a.value, min(a.index, b.index));
    if (is_nan(a.value)) return a;
    if (is_nan(b.value)) return b;
    return (a.value >= b.value) ? a : b;
}
template <typename T>
__device__ min_max_st<T> my_argmax_complex(
        const min_max_st<T>& a, const min_max_st<T>& b) {
    if (a.index == -1) return b;
    if (b.index == -1) return a;
    if (a.value == b.value)
        return min_max_st<T>(a.value, min(a.index, b.index));
    if (is_nan(a.value.real())) return a;
    if (is_nan(a.value.imag())) return a;
    if (is_nan(b.value.real())) return b;
    if (is_nan(b.value.imag())) return b;
    return (a.value >= b.value) ? a : b;
}
'''


cdef _amin = create_reduction_func(
    'cupy_min',
    ('?->?', 'b->b', 'B->B', 'h->h', 'H->H', 'i->i', 'I->I', 'l->l', 'L->L',
     'q->q', 'Q->Q',
     ('e->e', (None, 'my_min_float(a, b)', None, None)),
     ('f->f', (None, 'my_min_float(a, b)', None, None)),
     ('d->d', (None, 'my_min_float(a, b)', None, None)),
     ('F->F', (None, 'my_min_complex(a, b)', None, None)),
     ('D->D', (None, 'my_min_complex(a, b)', None, None))),
    ('min_max_st<type_in0_raw>(in0)', 'my_min(a, b)', 'out0 = a.value',
     'min_max_st<type_in0_raw>'),
    None, _min_max_preamble)


cdef _amax = create_reduction_func(
    'cupy_max',
    ('?->?', 'b->b', 'B->B', 'h->h', 'H->H', 'i->i', 'I->I', 'l->l', 'L->L',
     'q->q', 'Q->Q',
     ('e->e', (None, 'my_max_float(a, b)', None, None)),
     ('f->f', (None, 'my_max_float(a, b)', None, None)),
     ('d->d', (None, 'my_max_float(a, b)', None, None)),
     ('F->F', (None, 'my_max_complex(a, b)', None, None)),
     ('D->D', (None, 'my_max_complex(a, b)', None, None)),
     ),
    ('min_max_st<type_in0_raw>(in0)', 'my_max(a, b)', 'out0 = a.value',
     'min_max_st<type_in0_raw>'),
    None, _min_max_preamble)


nanmin = create_reduction_func(
    'cupy_nanmin',
    ('?->?', 'b->b', 'B->B', 'h->h', 'H->H', 'i->i', 'I->I', 'l->l', 'L->L',
     'q->q', 'Q->Q', 'e->e', 'f->f', 'd->d'),
    ('min_max_st<type_in0_raw>(in0)', 'my_min(a, b)', 'out0 = a.value',
     'min_max_st<type_in0_raw>'),
    None, _min_max_preamble)


nanmax = create_reduction_func(
    'cupy_nanmax',
    ('?->?', 'b->b', 'B->B', 'h->h', 'H->H', 'i->i', 'I->I', 'l->l', 'L->L',
     'q->q', 'Q->Q', 'e->e', 'f->f', 'd->d'),
    ('min_max_st<type_in0_raw>(in0)', 'my_max(a, b)', 'out0 = a.value',
     'min_max_st<type_in0_raw>'),
    None, _min_max_preamble)


cdef _argmin = create_reduction_func(
    'cupy_argmin',
    ('?->q', 'B->q', 'h->q', 'H->q', 'i->q', 'I->q', 'l->q', 'L->q',
     'q->q', 'Q->q',
     ('e->q', (None, 'my_argmin_float(a, b)', None, None)),
     ('f->q', (None, 'my_argmin_float(a, b)', None, None)),
     ('d->q', (None, 'my_argmin_float(a, b)', None, None)),
     ('F->q', (None, 'my_argmin_complex(a, b)', None, None)),
     ('D->q', (None, 'my_argmin_complex(a, b)', None, None))),
    ('min_max_st<type_in0_raw>(in0, _J)', 'my_argmin(a, b)', 'out0 = a.index',
     'min_max_st<type_in0_raw>'),
    None, _min_max_preamble)


cdef _argmax = create_reduction_func(
    'cupy_argmax',
    ('?->q', 'B->q', 'h->q', 'H->q', 'i->q', 'I->q', 'l->q', 'L->q',
     'q->q', 'Q->q',
     ('e->q', (None, 'my_argmax_float(a, b)', None, None)),
     ('f->q', (None, 'my_argmax_float(a, b)', None, None)),
     ('d->q', (None, 'my_argmax_float(a, b)', None, None)),
     ('F->q', (None, 'my_argmax_complex(a, b)', None, None)),
     ('D->q', (None, 'my_argmax_complex(a, b)', None, None))),
    ('min_max_st<type_in0_raw>(in0, _J)', 'my_argmax(a, b)', 'out0 = a.index',
     'min_max_st<type_in0_raw>'),
    None, _min_max_preamble)


cdef ndarray _var(
        ndarray a, axis=None, dtype=None, out=None, ddof=0, keepdims=False):
    assert a.dtype.kind != 'c', 'Variance for complex numbers is not ' \
                                'implemented. Current implemention does not ' \
                                'convert the dtype'
    if axis is None:
        axis = tuple(range(a.ndim))
    if not isinstance(axis, tuple):
        axis = (axis,)

    if dtype is None and a.dtype.kind in 'biu':
        dtype = 'd'

    shape = a.shape
    items = 1
    for ax in axis:
        items *= shape[ax]
    alpha = 1. / max(items - ddof, 0)
    arrmean = a.mean(axis=axis, dtype=dtype, out=None, keepdims=True)
    if out is None:
        return _var_core(a, arrmean, alpha, axis=axis, keepdims=keepdims)
    else:
        return _var_core_out(
            a, arrmean, alpha, out, axis=axis, keepdims=keepdims)


cdef ndarray _std(
        ndarray a, axis=None, dtype=None, out=None, ddof=0, keepdims=False):
    ret = _var(
        a, axis=axis, dtype=dtype, out=None, ddof=ddof, keepdims=keepdims)
    return _math._sqrt(ret, dtype=dtype, out=out)


cdef _var_core = ReductionKernel(
    'S x, T mean, T alpha', 'T out',
    '(x - mean) * (x - mean)',
    'a + b', 'out = alpha * a', '0', '_var_core')

cdef _var_core_out = ReductionKernel(
    'S x, T mean, T alpha', 'U out',
    '(x - mean) * (x - mean)',
    'a + b', 'out = alpha * a', '0', '_var_core')

# TODO(okuta) needs cast
cdef _mean = create_reduction_func(
    'cupy_mean',
    ('?->d', 'B->d', 'h->d', 'H->d', 'i->d', 'I->d', 'l->d', 'L->d',
     'q->d', 'Q->d',
     ('e->e', (None, None, None, 'float')),
     'f->f', 'd->d', 'F->F', 'D->D'),
    ('in0', 'a + b',
     'out0 = a / _type_reduce(_in_ind.size() / _out_ind.size())', None))


cdef _nan_mean_var_preamble = '''
template <typename T>
struct nan_mean_var_st{
    T value;
    int count;
    __device__ nan_mean_var_st() : count(-1) { }
    __device__ nan_mean_var_st(T v) : value(v), count(is_nan(v) ? 0 : 1) { }
    __device__ nan_mean_var_st(T v, int c) : value(v), count(c) { }
};

template <typename T>
inline __device__ bool is_nan(T x) {
    return x != x;
}

template <typename T>
__device__ nan_mean_var_st<T> my_nanmean_float(
        const nan_mean_var_st<T>& a, const nan_mean_var_st<T>& b) {
    if (a.count == -1) return b;
    if (b.count == -1) return a;
    if (is_nan(a.value)) return b;
    if (is_nan(b.value)) return a;
    return nan_mean_var_st<T>(a.value + b.value, a.count + b.count);
}

template <typename T>
__device__ nan_mean_var_st<T> my_nanmean_complex(
        const nan_mean_var_st<T>& a, const nan_mean_var_st<T>& b) {
    if (a.count == -1) return b;
    if (b.count == -1) return a;
    if (is_nan(a.value.real())) return b;
    if (is_nan(a.value.imag())) return b;
    if (is_nan(b.value.real())) return a;
    if (is_nan(b.value.imag())) return a;
    return nan_mean_var_st<T>(a.value + b.value, a.count + b.count);
}
'''


cdef _nanmean = create_reduction_func(
    'cupy_nanmean',
    (('e->e', (None, 'my_nanmean_float(a, b)', None, None)),
     ('f->f', (None, 'my_nanmean_float(a, b)', None, None)),
     ('d->d', (None, 'my_nanmean_float(a, b)', None, None)),
     ('F->F', (None, 'my_nanmean_complex(a, b)',
      'out0 = a.value / type_out0_raw(a.count)', None)),
     ('D->D', (None, 'my_nanmean_complex(a, b)',
      'out0 = a.value / type_out0_raw(a.count)', None))),
    ('in0', None,
     'out0 = a.value / a.count', 'nan_mean_var_st<type_out0_raw>'),
    None, _nan_mean_var_preamble)


# Variables to expose to Python
# (cythonized data cannot be exposed to Python, even with cpdef.)


amax = _amax
amin = _amin
