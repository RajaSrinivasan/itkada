with Itklib.Images;
with Itklib.Process_Object;
with Itklib.Supported;

generic
   with package Img is new Itklib.Images (<>);
package Itklib.Filters.Image_Grid.Flip with SPARK_Mode => Off is
   pragma Compile_Time_Error
     (not Itklib.Supported.Flip (Img.Pixel_Kind_Id, Img.Image_Dimension),
      "Flip is not built for this pixel kind and dimension");

   --  itk::FlipImageFilter. True flips that axis. Flip_About_Origin is
   --  ITK's default (True): the origin moves so the physical extent stays
   --  put. adaimg -flip x|y sets one axis and leaves the default origin rule.

   type Axis_Flags is array (Img.Axis) of Boolean;

   type Filter is limited new Itklib.Process_Object.Object with private;

   function Create return Filter;
   procedure Set_Input (F : in out Filter; Image : Img.Image);
   procedure Set_Flip_Axes (F : in out Filter; Axes : Axis_Flags);
   procedure Set_Flip_About_Origin (F : in out Filter; Enabled : Boolean);
   function Get_Output (F : Filter) return Img.Image;

private
   type Filter is limited new Itklib.Process_Object.Object with record
      Axes : Axis_Flags := [others => False];
      About_Origin : Boolean := True;
   end record;
end Itklib.Filters.Image_Grid.Flip;
