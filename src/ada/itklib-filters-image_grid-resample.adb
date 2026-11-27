with Interfaces.C;
with Itklib.Thin;

package body Itklib.Filters.Image_Grid.Resample with SPARK_Mode => Off is
   use type Interfaces.Unsigned_64;

   function Ready (Extent : Input.Size) return Boolean is
      (for all Item of Extent => Item > 0);

   procedure Push (F : Filter) is
      Raw_Size : Thin.Extent_Array (1 .. Input.Image_Dimension);
      Raw_Spacing : Thin.Double_Array (1 .. Input.Image_Dimension);
      Raw_Origin : Thin.Double_Array (1 .. Input.Image_Dimension);
      Raw_Direction : Thin.Double_Array (1 .. Input.Image_Dimension * Input.Image_Dimension);
      K : Positive := 1;
      Slot : Positive := 1;
   begin
      if not Ready (F.Extent) then
         return;
      end if;
      for Item of F.Extent loop
         Raw_Size (K) := Item;
         K := K + 1;
      end loop;
      K := 1;
      for Item of F.Spacing loop
         Raw_Spacing (K) := Interfaces.C.double (Item);
         K := K + 1;
      end loop;
      K := 1;
      for Item of F.Origin loop
         Raw_Origin (K) := Interfaces.C.double (Item);
         K := K + 1;
      end loop;
      for Row in Input.Axis loop
         for Column in Input.Axis loop
            Raw_Direction (Slot) := Interfaces.C.double (F.Direction (Row, Column));
            Slot := Slot + 1;
         end loop;
      end loop;
      Thin.Resample_Configure
        (F.Raw_Handle, Raw_Size, Raw_Spacing, Raw_Origin, Raw_Direction,
         F.Default_Pixel);
   end Push;

   function Create return Filter is
   begin
      return Result : Filter do
         Result.Set_Raw_Handle
           (Thin.Filter_New
              (Thin.Resample, Input.Pixel_Kind_Id, Input.Image_Dimension));
         for Axis_Id in Input.Axis loop
            Result.Direction (Axis_Id, Axis_Id) := 1.0;
         end loop;
      end return;
   end Create;

   procedure Set_Input (F : in out Filter; Image : Input.Image) is
   begin
      Thin.Set_Input (F.Raw_Handle, Image.Raw_Handle);
   end Set_Input;

   procedure Set_Output_Size (F : in out Filter; Extent : Input.Size) is
   begin
      F.Extent := Extent;
      Push (F);
   end Set_Output_Size;

   procedure Set_Output_Spacing (F : in out Filter; Value : Input.Vector) is
   begin
      F.Spacing := Value;
      Push (F);
   end Set_Output_Spacing;

   procedure Set_Output_Origin (F : in out Filter; Value : Input.Vector) is
   begin
      F.Origin := Value;
      Push (F);
   end Set_Output_Origin;

   procedure Set_Output_Direction (F : in out Filter; Value : Input.Direction) is
   begin
      F.Direction := Value;
      Push (F);
   end Set_Output_Direction;

   procedure Set_Default_Pixel (F : in out Filter; Value : Long_Float) is
   begin
      F.Default_Pixel := Value;
      Push (F);
   end Set_Default_Pixel;

   procedure Set_Uniform_Scale (F : in out Filter; Scale : Long_Float) is
   begin
      Thin.Resample_Set_Uniform_Scale (F.Raw_Handle, Scale);
   end Set_Uniform_Scale;

   function Get_Output (F : Filter) return Output.Image is
   begin
      return Output.From_Handle (Thin.Get_Output (F.Raw_Handle));
   end Get_Output;

begin
   if Input.Pixel_Kind_Id /= Output.Pixel_Kind_Id
     or else Input.Image_Dimension /= Output.Image_Dimension
   then
      raise Unsupported_Instantiation with
        "Resample requires matching input and output images";
   end if;
   if not Thin.Is_Supported (Input.Pixel_Kind_Id, Input.Image_Dimension) then
      raise Unsupported_Instantiation with
        "Resample is not built for this pixel kind and dimension";
   end if;
end Itklib.Filters.Image_Grid.Resample;
