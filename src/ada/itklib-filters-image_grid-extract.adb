with Interfaces;
with Itklib.Thin;

package body Itklib.Filters.Image_Grid.Extract with SPARK_Mode => Off is
   use type Interfaces.Integer_64;
   use type Interfaces.Unsigned_64;

   function Known (Region : Input.Region) return Boolean is
      (for all Item of Region.Extent => Item > 0);

   function Inside (Outer, Inner : Input.Region) return Boolean is
   begin
      for Axis_Id in Input.Axis loop
         if Inner.Start (Axis_Id) < Outer.Start (Axis_Id) then
            return False;
         end if;
         declare
            Inner_Last : constant Interfaces.Integer_64 :=
              Inner.Start (Axis_Id) + Interfaces.Integer_64 (Inner.Extent (Axis_Id)) - 1;
            Outer_Last : constant Interfaces.Integer_64 :=
              Outer.Start (Axis_Id) + Interfaces.Integer_64 (Outer.Extent (Axis_Id)) - 1;
         begin
            if Inner_Last > Outer_Last then
               return False;
            end if;
         end;
      end loop;
      return True;
   end Inside;

   function Create return Filter is
   begin
      return Result : Filter do
         Result.Set_Raw_Handle
           (Thin.Filter_New
              (Thin.Extract, Input.Pixel_Kind_Id, Input.Image_Dimension));
      end return;
   end Create;

   procedure Set_Input (F : in out Filter; Image : Input.Image) is
      Region : constant Input.Region := Input.Largest_Possible_Region (Image);
   begin
      Thin.Set_Input (F.Raw_Handle, Image.Raw_Handle);
      F.Input_Region := Region;
      F.Known_Input := Known (Region);
   end Set_Input;

   procedure Set_Extraction_Region (F : in out Filter; Value : Input.Region) is
      Start : Thin.Index_Array (1 .. Input.Image_Dimension);
      Extent : Thin.Extent_Array (1 .. Input.Image_Dimension);
      K : Positive := 1;
   begin
      if F.Known_Input and then not Inside (F.Input_Region, Value) then
         raise Itk_Error with "extraction region is outside the input image";
      end if;
      for Item of Value.Start loop
         Start (K) := Item;
         K := K + 1;
      end loop;
      K := 1;
      for Item of Value.Extent loop
         Extent (K) := Item;
         K := K + 1;
      end loop;
      Thin.Extract_Set_Region (F.Raw_Handle, Start, Extent);
   end Set_Extraction_Region;

   function Get_Output (F : Filter) return Output.Image is
   begin
      return Output.From_Handle (Thin.Get_Output (F.Raw_Handle));
   end Get_Output;

begin
   if Input.Pixel_Kind_Id /= Output.Pixel_Kind_Id
     or else Input.Image_Dimension /= Output.Image_Dimension
   then
      raise Unsupported_Instantiation with
        "Extract requires matching input and output images";
   end if;
   if not Thin.Is_Supported (Input.Pixel_Kind_Id, Input.Image_Dimension) then
      raise Unsupported_Instantiation with
        "Extract is not built for this pixel kind and dimension";
   end if;
end Itklib.Filters.Image_Grid.Extract;
