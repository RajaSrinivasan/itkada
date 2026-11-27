with Itklib.Images;
with Itklib.Process_Object;

generic
   with package Input is new Itklib.Images (<>);
   with package Output is new Itklib.Images (<>);
package Itklib.Filters.Smoothing.Discrete_Gaussian with SPARK_Mode => Off is
   type Filter is limited new Itklib.Process_Object.Object with private;

   function Create return Filter;
   procedure Set_Input (F : in out Filter; Image : Input.Image);
   procedure Set_Variance (F : in out Filter; Value : Input.Vector);
   procedure Set_Maximum_Error (F : in out Filter; Value : Input.Vector);
   procedure Set_Use_Image_Spacing (F : in out Filter; Enabled : Boolean);
   function Get_Output (F : Filter) return Output.Image;

private
   type Filter is limited new Itklib.Process_Object.Object with null record;
end Itklib.Filters.Smoothing.Discrete_Gaussian;
