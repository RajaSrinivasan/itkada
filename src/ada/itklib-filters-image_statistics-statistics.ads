with Itklib.Images;
with Itklib.Process_Object;

generic
   with package Img is new Itklib.Images (<>);
package Itklib.Filters.Image_Statistics.Statistics with SPARK_Mode => Off is
   --  itk::StatisticsImageFilter (an image sink: it has no image output).
   --  Call Update, then Minimum, Maximum, and Mean. adaimg identify uses
   --  those values together with the image region and spacing.

   type Filter is limited new Itklib.Process_Object.Object with private;

   function Create return Filter;
   procedure Set_Input (F : in out Filter; Image : Img.Image);
   function Minimum (F : Filter) return Long_Float;
   function Maximum (F : Filter) return Long_Float;
   function Mean (F : Filter) return Long_Float;

private
   type Filter is limited new Itklib.Process_Object.Object with null record;
end Itklib.Filters.Image_Statistics.Statistics;
