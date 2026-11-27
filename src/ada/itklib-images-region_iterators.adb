package body Itklib.Images.Region_Iterators with SPARK_Mode => Off is

   procedure Walk (R : Region) is
      procedure Inner is new Regions.Walk (Visit);
   begin
      Inner (R);
   end Walk;

end Itklib.Images.Region_Iterators;
