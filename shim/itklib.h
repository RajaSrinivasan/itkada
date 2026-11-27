#ifndef ITKLIB_H
#define ITKLIB_H

/* C ABI for the itklib shim. Ada includes this surface only; every
   function catches C++ exceptions and reports them through itklib_error. */

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct itklib_object itklib_object;

/* Scalar ids match SimpleITK PixelIDValueEnum. Only UInt16 is built. */
typedef enum itklib_pixel_id {
  ITKLIB_UINT8 = 1,
  ITKLIB_INT8 = 2,
  ITKLIB_UINT16 = 3,
  ITKLIB_INT16 = 4,
  ITKLIB_UINT32 = 5,
  ITKLIB_INT32 = 6,
  ITKLIB_UINT64 = 7,
  ITKLIB_INT64 = 8,
  ITKLIB_FLOAT32 = 9,
  ITKLIB_FLOAT64 = 10
} itklib_pixel_id;

enum {
  ITKLIB_OK = 0,
  ITKLIB_E_ITK = 1,
  ITKLIB_E_UNSUPPORTED = 2,
  ITKLIB_E_BAD_ALLOC = 3,
  ITKLIB_E_STD = 4,
  ITKLIB_E_UNKNOWN = 5,
  ITKLIB_E_NULL = 6,
  ITKLIB_E_ARG = 7
};

typedef struct itklib_error {
  int code;
  char what[1024];
  char where[256];
} itklib_error;

const char * itklib_itk_version (void);

int itklib_supported (itklib_pixel_id pixel, unsigned dimension);

void itklib_register (itklib_object * object);
void itklib_unregister (itklib_object * object);
int itklib_reference_count (itklib_object * object);
int itklib_debug_live_objects (void);
int itklib_debug_live_wrappers (void);

int itklib_image_new (itklib_pixel_id pixel, unsigned dimension,
                      const uint64_t * size, itklib_object ** out,
                      itklib_error * error);

int itklib_image_buffer (itklib_object * image, void ** data,
                         uint64_t * count, itklib_error * error);

int itklib_image_get_geometry (itklib_object * image, int64_t * index,
                               uint64_t * size, double * spacing,
                               double * origin, double * direction,
                               itklib_error * error);

int itklib_image_set_spacing (itklib_object * image, const double * spacing,
                              itklib_error * error);
int itklib_image_set_origin (itklib_object * image, const double * origin,
                             itklib_error * error);
int itklib_image_set_direction (itklib_object * image,
                                const double * direction,
                                itklib_error * error);

int itklib_reader_new (itklib_pixel_id pixel, unsigned dimension,
                       itklib_object ** out, itklib_error * error);
int itklib_reader_set_file (itklib_object * reader, const char * path,
                            itklib_error * error);

int itklib_writer_new (itklib_pixel_id pixel, unsigned dimension,
                       itklib_object ** out, itklib_error * error);
int itklib_writer_set_file (itklib_object * writer, const char * path,
                            itklib_error * error);

int itklib_discrete_gaussian_new (itklib_pixel_id input_pixel,
                                  itklib_pixel_id output_pixel,
                                  unsigned dimension, itklib_object ** out,
                                  itklib_error * error);
int itklib_discrete_gaussian_set_variance (itklib_object * filter,
                                           const double * variance,
                                           itklib_error * error);
int itklib_discrete_gaussian_set_use_image_spacing (itklib_object * filter,
                                                    int enabled,
                                                    itklib_error * error);
int itklib_discrete_gaussian_set_maximum_error (itklib_object * filter,
                                                const double * maximum_error,
                                                itklib_error * error);

enum {
  ITKLIB_FILTER_MEDIAN = 1,
  ITKLIB_FILTER_THRESHOLD = 2,
  ITKLIB_FILTER_RESCALE = 3,
  ITKLIB_FILTER_SHRINK = 4,
  ITKLIB_FILTER_RESAMPLE = 5,
  ITKLIB_FILTER_FLIP = 6,
  ITKLIB_FILTER_EXTRACT = 7,
  ITKLIB_FILTER_GRADIENT = 8,
  ITKLIB_FILTER_STATISTICS = 9
};

int itklib_filter_new (int kind, itklib_pixel_id pixel, unsigned dimension,
                       itklib_object ** out, itklib_error * error);
int itklib_median_set_radius (itklib_object * filter, const uint64_t * radius,
                              itklib_error * error);
int itklib_threshold_set (itklib_object * filter, double lower, double upper,
                          double inside_value, double outside_value,
                          itklib_error * error);
int itklib_rescale_set_output_range (itklib_object * filter, double minimum,
                                     double maximum, itklib_error * error);
int itklib_shrink_set_factors (itklib_object * filter, const uint64_t * factors,
                               itklib_error * error);
int itklib_resample_configure (itklib_object * filter, const uint64_t * size,
                               const double * spacing, const double * origin,
                               const double * direction, double default_pixel,
                               itklib_error * error);
int itklib_resample_set_uniform_scale (itklib_object * filter, double scale,
                                       itklib_error * error);
int itklib_flip_set_axes (itklib_object * filter, const int * axes,
                          int about_origin, itklib_error * error);
int itklib_extract_set_region (itklib_object * filter, const int64_t * index,
                               const uint64_t * size, itklib_error * error);
int itklib_gradient_set_use_image_spacing (itklib_object * filter, int enabled,
                                           itklib_error * error);
int itklib_statistics_get (itklib_object * filter, double * minimum,
                           double * maximum, double * mean, itklib_error * error);

int itklib_set_input (itklib_object * filter, unsigned index,
                      itklib_object * image, itklib_error * error);
int itklib_update (itklib_object * process, itklib_error * error);
int itklib_modified (itklib_object * process, itklib_error * error);
int itklib_update_largest_possible_region (itklib_object * process,
                                           itklib_error * error);
int itklib_set_number_of_work_units (itklib_object * process, unsigned count,
                                     itklib_error * error);
int itklib_get_output (itklib_object * process, unsigned index,
                       itklib_object ** image, itklib_error * error);

int itklib_image_buffer_lock (itklib_object * image, itklib_error * error);
int itklib_image_buffer_unlock (itklib_object * image, itklib_error * error);
int itklib_image_disconnect (itklib_object * image, itklib_error * error);
int itklib_image_index_to_physical (itklib_object * image, const int64_t * index,
                                    double * point, itklib_error * error);
int itklib_image_physical_to_index (itklib_object * image, const double * point,
                                    int64_t * index, itklib_error * error);

#ifdef __cplusplus
}
#endif

#endif /* ITKLIB_H */
