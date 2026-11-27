with Ada.Unchecked_Conversion;
with Interfaces.C.Strings;

package body Itklib.Thin with SPARK_Mode => Off is

   use type Interfaces.C.int;
   use type Interfaces.Unsigned_64;
   use type System.Address;

   type Object is null record with Convention => C;
   type Object_Ptr is access all Object with Convention => C, Storage_Size => 0;

   function Address_To_Pointer is new Ada.Unchecked_Conversion
     (System.Address, Object_Ptr);
   function Pointer_To_Address is new Ada.Unchecked_Conversion
     (Object_Ptr, System.Address);

   type Error_Record is record
      Code : Interfaces.C.int;
      What : Interfaces.C.char_array (1 .. 1024);
      Where : Interfaces.C.char_array (1 .. 256);
   end record
     with Convention => C;

   type C_U64_Array is
     array (Natural range <>) of aliased Interfaces.Unsigned_64
     with Convention => C;
   type C_I64_Array is
     array (Natural range <>) of aliased Interfaces.Integer_64
     with Convention => C;
   type C_F64_Array is
     array (Natural range <>) of aliased Interfaces.C.double
     with Convention => C;

   function To_Pointer (Handle : System.Address) return Object_Ptr is
     (if Handle = System.Null_Address then null else Address_To_Pointer (Handle));

   function To_Handle (Pointer : Object_Ptr) return System.Address is
     (if Pointer = null then System.Null_Address
      else Pointer_To_Address (Pointer));

   function Pixel_Id (Kind : Itklib.Pixel_Kind) return Interfaces.C.int is
   begin
      case Kind is
         when Itklib.UInt8 =>
            return 1;
         when Itklib.Int8 =>
            return 2;
         when Itklib.UInt16 =>
            return 3;
         when Itklib.Int16 =>
            return 4;
         when Itklib.UInt32 =>
            return 5;
         when Itklib.Int32 =>
            return 6;
         when Itklib.UInt64 =>
            return 7;
         when Itklib.Int64 =>
            return 8;
         when Itklib.Float32 =>
            return 9;
         when Itklib.Float64 =>
            return 10;
      end case;
   end Pixel_Id;

   function Message (Error : Error_Record) return String is
      What : constant String :=
        Interfaces.C.To_Ada (Error.What, Trim_Nul => True);
      Where : constant String :=
        Interfaces.C.To_Ada (Error.Where, Trim_Nul => True);
   begin
      if Where'Length = 0 then
         return What;
      else
         return What & " (" & Where & ")";
      end if;
   end Message;

   procedure Check (Code : Interfaces.C.int; Error : Error_Record) is
   begin
      case Code is
         when 0 =>
            null;
         when 2 =>
            raise Itklib.Unsupported_Instantiation with Message (Error);
         when 3 =>
            raise Storage_Error with Message (Error);
         when others =>
            raise Itklib.Itk_Error with Message (Error);
      end case;
   end Check;

   procedure Require (Handle : System.Address) is
   begin
      if Handle = System.Null_Address then
         raise Itklib.Itk_Error with "null ITK handle";
      end if;
   end Require;

   function As_Natural (Value : Interfaces.C.int) return Natural is
   begin
      if Value <= 0 then
         return 0;
      end if;
      return Natural (Value);
   end As_Natural;

   function itklib_itk_version return Interfaces.C.Strings.chars_ptr with
     Import, Convention => C, External_Name => "itklib_itk_version";

   function itklib_supported
     (Pixel : Interfaces.C.int; Dimension : Interfaces.C.unsigned)
      return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_supported";

   procedure itklib_register (Object : Object_Ptr) with
     Import, Convention => C, External_Name => "itklib_register";

   procedure itklib_unregister (Object : Object_Ptr) with
     Import, Convention => C, External_Name => "itklib_unregister";

   function itklib_reference_count (Object : Object_Ptr) return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_reference_count";

   function itklib_debug_live_objects return Interfaces.C.int with
     Import, Convention => C, External_Name => "itklib_debug_live_objects";

   function itklib_debug_live_wrappers return Interfaces.C.int with
     Import, Convention => C, External_Name => "itklib_debug_live_wrappers";

   function itklib_image_new
     (Pixel : Interfaces.C.int; Dimension : Interfaces.C.unsigned;
      Size : access constant Interfaces.Unsigned_64;
      Out_Object : access Object_Ptr; Error : access Error_Record)
      return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_image_new";

   function itklib_image_buffer
     (Image : Object_Ptr; Data : access System.Address;
      Count : access Interfaces.Unsigned_64; Error : access Error_Record)
      return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_image_buffer";

   function itklib_image_get_geometry
     (Image : Object_Ptr; Index : access Interfaces.Integer_64;
      Size : access Interfaces.Unsigned_64; Spacing : access Interfaces.C.double;
      Origin : access Interfaces.C.double; Direction : access Interfaces.C.double;
      Error : access Error_Record) return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_image_get_geometry";

   function itklib_image_set_spacing
     (Image : Object_Ptr; Spacing : access constant Interfaces.C.double;
      Error : access Error_Record) return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_image_set_spacing";

   function itklib_image_set_origin
     (Image : Object_Ptr; Origin : access constant Interfaces.C.double;
      Error : access Error_Record) return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_image_set_origin";

   function itklib_image_set_direction
     (Image : Object_Ptr; Direction : access constant Interfaces.C.double;
      Error : access Error_Record) return Interfaces.C.int
     with
       Import, Convention => C, External_Name => "itklib_image_set_direction";

   function itklib_reader_new
     (Pixel : Interfaces.C.int; Dimension : Interfaces.C.unsigned;
      Out_Object : access Object_Ptr; Error : access Error_Record)
      return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_reader_new";

   function itklib_reader_set_file
     (Reader : Object_Ptr; Path : Interfaces.C.Strings.chars_ptr;
      Error : access Error_Record) return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_reader_set_file";

   function itklib_writer_new
     (Pixel : Interfaces.C.int; Dimension : Interfaces.C.unsigned;
      Out_Object : access Object_Ptr; Error : access Error_Record)
      return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_writer_new";

   function itklib_writer_set_file
     (Writer : Object_Ptr; Path : Interfaces.C.Strings.chars_ptr;
      Error : access Error_Record) return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_writer_set_file";

   function itklib_discrete_gaussian_new
     (Input_Pixel : Interfaces.C.int; Output_Pixel : Interfaces.C.int;
      Dimension : Interfaces.C.unsigned; Out_Object : access Object_Ptr;
      Error : access Error_Record) return Interfaces.C.int
     with
       Import, Convention => C, External_Name => "itklib_discrete_gaussian_new";

   function itklib_discrete_gaussian_set_variance
     (Filter : Object_Ptr; Variance : access constant Interfaces.C.double;
      Error : access Error_Record) return Interfaces.C.int
     with
       Import,
       Convention => C,
       External_Name => "itklib_discrete_gaussian_set_variance";

   function itklib_discrete_gaussian_set_use_image_spacing
     (Filter : Object_Ptr; Enabled : Interfaces.C.int; Error : access Error_Record)
      return Interfaces.C.int
     with
       Import,
       Convention => C,
       External_Name => "itklib_discrete_gaussian_set_use_image_spacing";

   function itklib_discrete_gaussian_set_maximum_error
     (Filter : Object_Ptr; Maximum_Error : access constant Interfaces.C.double;
      Error : access Error_Record) return Interfaces.C.int
     with
       Import,
       Convention => C,
       External_Name => "itklib_discrete_gaussian_set_maximum_error";

   function itklib_filter_new
     (Kind : Interfaces.C.int; Pixel : Interfaces.C.int;
      Dimension : Interfaces.C.unsigned; Out_Object : access Object_Ptr;
      Error : access Error_Record) return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_filter_new";

   function itklib_median_set_radius
     (Filter : Object_Ptr; Radius : access constant Interfaces.Unsigned_64;
      Error : access Error_Record) return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_median_set_radius";

   function itklib_threshold_set
     (Filter : Object_Ptr; Lower, Upper, Inside_Value, Outside_Value : Interfaces.C.double;
      Error : access Error_Record) return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_threshold_set";

   function itklib_rescale_set_output_range
     (Filter : Object_Ptr; Minimum, Maximum : Interfaces.C.double;
      Error : access Error_Record) return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_rescale_set_output_range";

   function itklib_shrink_set_factors
     (Filter : Object_Ptr; Factors : access constant Interfaces.Unsigned_64;
      Error : access Error_Record) return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_shrink_set_factors";

   function itklib_resample_configure
     (Filter : Object_Ptr; Size : access constant Interfaces.Unsigned_64;
      Spacing, Origin, Direction : access constant Interfaces.C.double;
      Default_Pixel : Interfaces.C.double; Error : access Error_Record)
      return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_resample_configure";

   function itklib_resample_set_uniform_scale
     (Filter : Object_Ptr; Scale : Interfaces.C.double; Error : access Error_Record)
      return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_resample_set_uniform_scale";

   function itklib_flip_set_axes
     (Filter : Object_Ptr; Axes : access constant Interfaces.C.int;
      About_Origin : Interfaces.C.int; Error : access Error_Record)
      return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_flip_set_axes";

   function itklib_extract_set_region
     (Filter : Object_Ptr; Index : access constant Interfaces.Integer_64;
      Size : access constant Interfaces.Unsigned_64; Error : access Error_Record)
      return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_extract_set_region";

   function itklib_gradient_set_use_image_spacing
     (Filter : Object_Ptr; Enabled : Interfaces.C.int; Error : access Error_Record)
      return Interfaces.C.int
     with
       Import, Convention => C, External_Name => "itklib_gradient_set_use_image_spacing";

   function itklib_statistics_get
     (Filter : Object_Ptr; Minimum, Maximum, Mean : access Interfaces.C.double;
      Error : access Error_Record) return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_statistics_get";

   function itklib_modified
     (Process : Object_Ptr; Error : access Error_Record) return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_modified";

   function itklib_update_largest_possible_region
     (Process : Object_Ptr; Error : access Error_Record) return Interfaces.C.int
     with
       Import, Convention => C, External_Name => "itklib_update_largest_possible_region";

   function itklib_set_number_of_work_units
     (Process : Object_Ptr; Count : Interfaces.C.unsigned; Error : access Error_Record)
      return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_set_number_of_work_units";

   function itklib_image_buffer_lock
     (Image : Object_Ptr; Error : access Error_Record) return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_image_buffer_lock";

   function itklib_image_buffer_unlock
     (Image : Object_Ptr; Error : access Error_Record) return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_image_buffer_unlock";

   function itklib_image_disconnect
     (Image : Object_Ptr; Error : access Error_Record) return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_image_disconnect";

   function itklib_image_index_to_physical
     (Image : Object_Ptr; Index : access constant Interfaces.Integer_64;
      Point : access Interfaces.C.double; Error : access Error_Record)
      return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_image_index_to_physical";

   function itklib_image_physical_to_index
     (Image : Object_Ptr; Point : access constant Interfaces.C.double;
      Index : access Interfaces.Integer_64; Error : access Error_Record)
      return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_image_physical_to_index";

   function itklib_set_input
     (Filter : Object_Ptr; Index : Interfaces.C.unsigned; Image : Object_Ptr;
      Error : access Error_Record) return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_set_input";

   function itklib_update
     (Process : Object_Ptr; Error : access Error_Record) return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_update";

   function itklib_get_output
     (Process : Object_Ptr; Index : Interfaces.C.unsigned;
      Image : access Object_Ptr; Error : access Error_Record)
      return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_get_output";

   function ITK_Version return String is
   begin
      return Interfaces.C.Strings.Value (itklib_itk_version);
   end ITK_Version;

   function Is_Supported
     (Kind : Itklib.Pixel_Kind; Dimension : Positive) return Boolean is
   begin
      return
        itklib_supported (Pixel_Id (Kind), Interfaces.C.unsigned (Dimension))
        /= 0;
   end Is_Supported;

   function Debug_Live_Objects return Natural is
   begin
      return As_Natural (itklib_debug_live_objects);
   end Debug_Live_Objects;

   function Debug_Live_Wrappers return Natural is
   begin
      return As_Natural (itklib_debug_live_wrappers);
   end Debug_Live_Wrappers;

   procedure Register (Handle : System.Address) is
   begin
      if Handle /= System.Null_Address then
         itklib_register (To_Pointer (Handle));
      end if;
   end Register;

   procedure Unregister (Handle : System.Address) is
   begin
      if Handle /= System.Null_Address then
         itklib_unregister (To_Pointer (Handle));
      end if;
   end Unregister;

   function Reference_Count (Handle : System.Address) return Natural is
   begin
      if Handle = System.Null_Address then
         return 0;
      end if;
      return As_Natural (itklib_reference_count (To_Pointer (Handle)));
   end Reference_Count;

   function Image_New
     (Kind : Itklib.Pixel_Kind; Extent : Extent_Array) return System.Address
   is
      Size : C_U64_Array (0 .. Extent'Length - 1);
      Out_Object : aliased Object_Ptr := null;
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
   begin
      for K in Extent'Range loop
         Size (K - Extent'First) := Extent (K);
      end loop;
      Code :=
        itklib_image_new
          (Pixel_Id (Kind), Interfaces.C.unsigned (Extent'Length),
           Size (0)'Unchecked_Access, Out_Object'Unchecked_Access,
           Error'Unchecked_Access);
      Check (Code, Error);
      return To_Handle (Out_Object);
   end Image_New;

   procedure Image_Buffer
     (Handle : System.Address; Data : out System.Address;
      Count : out Interfaces.Unsigned_64)
   is
      Data_Slot : aliased System.Address := System.Null_Address;
      Count_Slot : aliased Interfaces.Unsigned_64 := 0;
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
   begin
      Require (Handle);
      Code :=
        itklib_image_buffer
          (To_Pointer (Handle), Data_Slot'Unchecked_Access,
           Count_Slot'Unchecked_Access, Error'Unchecked_Access);
      Check (Code, Error);
      Data := Data_Slot;
      Count := Count_Slot;
   end Image_Buffer;

   procedure Image_Get_Geometry
     (Handle : System.Address; Index : out Index_Array; Size : out Extent_Array;
      Spacing : out Double_Array; Origin : out Double_Array;
      Direction : out Double_Array)
   is
      N : constant Natural := Index'Length;
      C_Index : C_I64_Array (0 .. N - 1);
      C_Size : C_U64_Array (0 .. N - 1);
      C_Spacing : C_F64_Array (0 .. N - 1);
      C_Origin : C_F64_Array (0 .. N - 1);
      C_Direction : C_F64_Array (0 .. N * N - 1);
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
   begin
      Require (Handle);
      if Size'Length /= N or else Spacing'Length /= N or else Origin'Length /= N
        or else Direction'Length /= N * N
      then
         raise Itklib.Itk_Error with "geometry array lengths do not match";
      end if;
      Code :=
        itklib_image_get_geometry
          (To_Pointer (Handle), C_Index (0)'Unchecked_Access,
           C_Size (0)'Unchecked_Access, C_Spacing (0)'Unchecked_Access,
           C_Origin (0)'Unchecked_Access, C_Direction (0)'Unchecked_Access,
           Error'Unchecked_Access);
      Check (Code, Error);
      for K in 0 .. N - 1 loop
         Index (Index'First + K) := C_Index (K);
         Size (Size'First + K) := C_Size (K);
         Spacing (Spacing'First + K) := C_Spacing (K);
         Origin (Origin'First + K) := C_Origin (K);
      end loop;
      for K in C_Direction'Range loop
         Direction (Direction'First + K) := C_Direction (K);
      end loop;
   end Image_Get_Geometry;

   procedure Image_Set_Spacing
     (Handle : System.Address; Spacing : Double_Array)
   is
      Raw : C_F64_Array (0 .. Spacing'Length - 1);
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
   begin
      Require (Handle);
      for K in Spacing'Range loop
         Raw (K - Spacing'First) := Spacing (K);
      end loop;
      Code :=
        itklib_image_set_spacing
          (To_Pointer (Handle), Raw (0)'Unchecked_Access,
           Error'Unchecked_Access);
      Check (Code, Error);
   end Image_Set_Spacing;

   procedure Image_Set_Origin (Handle : System.Address; Origin : Double_Array) is
      Raw : C_F64_Array (0 .. Origin'Length - 1);
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
   begin
      Require (Handle);
      for K in Origin'Range loop
         Raw (K - Origin'First) := Origin (K);
      end loop;
      Code :=
        itklib_image_set_origin
          (To_Pointer (Handle), Raw (0)'Unchecked_Access, Error'Unchecked_Access);
      Check (Code, Error);
   end Image_Set_Origin;

   procedure Image_Set_Direction
     (Handle : System.Address; Direction : Double_Array)
   is
      Raw : C_F64_Array (0 .. Direction'Length - 1);
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
   begin
      Require (Handle);
      for K in Direction'Range loop
         Raw (K - Direction'First) := Direction (K);
      end loop;
      Code :=
        itklib_image_set_direction
          (To_Pointer (Handle), Raw (0)'Unchecked_Access,
           Error'Unchecked_Access);
      Check (Code, Error);
   end Image_Set_Direction;

   function Factory_New
     (Kind : Itklib.Pixel_Kind; Dimension : Positive; Which : Positive)
      return System.Address
   is
      Out_Object : aliased Object_Ptr := null;
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
      Pixel : constant Interfaces.C.int := Pixel_Id (Kind);
      Dim : constant Interfaces.C.unsigned := Interfaces.C.unsigned (Dimension);
   begin
      case Which is
         when 1 =>
            Code :=
              itklib_reader_new
                (Pixel, Dim, Out_Object'Unchecked_Access, Error'Unchecked_Access);
         when 2 =>
            Code :=
              itklib_writer_new
                (Pixel, Dim, Out_Object'Unchecked_Access, Error'Unchecked_Access);
         when others =>
            Code :=
              itklib_discrete_gaussian_new
                (Pixel, Pixel, Dim, Out_Object'Unchecked_Access,
                 Error'Unchecked_Access);
      end case;
      Check (Code, Error);
      return To_Handle (Out_Object);
   end Factory_New;

   function Reader_New
     (Kind : Itklib.Pixel_Kind; Dimension : Positive) return System.Address is
   begin
      return Factory_New (Kind, Dimension, 1);
   end Reader_New;

   function Writer_New
     (Kind : Itklib.Pixel_Kind; Dimension : Positive) return System.Address is
   begin
      return Factory_New (Kind, Dimension, 2);
   end Writer_New;

   function Gaussian_New
     (Kind : Itklib.Pixel_Kind; Dimension : Positive) return System.Address is
   begin
      return Factory_New (Kind, Dimension, 3);
   end Gaussian_New;

   procedure Set_File
     (Handle : System.Address; Path : String; Writer : Boolean)
   is
      use Interfaces.C.Strings;
      C_Path : chars_ptr := New_String (Path);
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
   begin
      Require (Handle);
      if Writer then
         Code :=
           itklib_writer_set_file
             (To_Pointer (Handle), C_Path, Error'Unchecked_Access);
      else
         Code :=
           itklib_reader_set_file
             (To_Pointer (Handle), C_Path, Error'Unchecked_Access);
      end if;
      Free (C_Path);
      Check (Code, Error);
   end Set_File;

   procedure Reader_Set_File (Handle : System.Address; Path : String) is
   begin
      Set_File (Handle, Path, False);
   end Reader_Set_File;

   procedure Writer_Set_File (Handle : System.Address; Path : String) is
   begin
      Set_File (Handle, Path, True);
   end Writer_Set_File;

   procedure Gaussian_Set_Variance
     (Handle : System.Address; Variance : Double_Array)
   is
      Raw : C_F64_Array (0 .. Variance'Length - 1);
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
   begin
      Require (Handle);
      for K in Variance'Range loop
         Raw (K - Variance'First) := Variance (K);
      end loop;
      Code :=
        itklib_discrete_gaussian_set_variance
          (To_Pointer (Handle), Raw (0)'Unchecked_Access, Error'Unchecked_Access);
      Check (Code, Error);
   end Gaussian_Set_Variance;

   procedure Gaussian_Set_Use_Image_Spacing
     (Handle : System.Address; Enabled : Boolean)
   is
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
      Flag : Interfaces.C.int := 0;
   begin
      Require (Handle);
      if Enabled then
         Flag := 1;
      end if;
      Code :=
        itklib_discrete_gaussian_set_use_image_spacing
          (To_Pointer (Handle), Flag, Error'Unchecked_Access);
      Check (Code, Error);
   end Gaussian_Set_Use_Image_Spacing;

   procedure Set_Input
     (Filter : System.Address; Image : System.Address; Index : Natural := 0)
   is
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
   begin
      Require (Filter);
      Require (Image);
      Code :=
        itklib_set_input
          (To_Pointer (Filter), Interfaces.C.unsigned (Index), To_Pointer (Image),
           Error'Unchecked_Access);
      Check (Code, Error);
   end Set_Input;

   procedure Update (Process : System.Address) is
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
   begin
      Require (Process);
      Code := itklib_update (To_Pointer (Process), Error'Unchecked_Access);
      Check (Code, Error);
   end Update;

   function Get_Output
     (Process : System.Address; Index : Natural := 0) return System.Address
   is
      Out_Object : aliased Object_Ptr := null;
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
   begin
      Require (Process);
      Code :=
        itklib_get_output
          (To_Pointer (Process), Interfaces.C.unsigned (Index),
           Out_Object'Unchecked_Access, Error'Unchecked_Access);
      Check (Code, Error);
      return To_Handle (Out_Object);
   end Get_Output;

   function Kind_Id (Kind : Filter_Kind) return Interfaces.C.int is
   begin
      case Kind is
         when Median =>
            return 1;
         when Threshold =>
            return 2;
         when Rescale =>
            return 3;
         when Shrink =>
            return 4;
         when Resample =>
            return 5;
         when Flip =>
            return 6;
         when Extract =>
            return 7;
         when Gradient =>
            return 8;
         when Statistics =>
            return 9;
      end case;
   end Kind_Id;

   function Filter_New
     (Kind : Filter_Kind; Pixel : Itklib.Pixel_Kind; Dimension : Positive)
      return System.Address
   is
      Out_Object : aliased Object_Ptr := null;
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
   begin
      Code :=
        itklib_filter_new
          (Kind_Id (Kind), Pixel_Id (Pixel), Interfaces.C.unsigned (Dimension),
           Out_Object'Unchecked_Access, Error'Unchecked_Access);
      Check (Code, Error);
      return To_Handle (Out_Object);
   end Filter_New;

   procedure Copy_U64 (Source : Extent_Array; Target : out C_U64_Array) is
   begin
      for K in Source'Range loop
         Target (K - Source'First) := Source (K);
      end loop;
   end Copy_U64;

   procedure Copy_F64 (Source : Double_Array; Target : out C_F64_Array) is
   begin
      for K in Source'Range loop
         Target (K - Source'First) := Source (K);
      end loop;
   end Copy_F64;

   procedure Median_Set_Radius (Handle : System.Address; Radius : Extent_Array) is
      Raw : C_U64_Array (0 .. Radius'Length - 1);
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
   begin
      Require (Handle);
      Copy_U64 (Radius, Raw);
      Code :=
        itklib_median_set_radius
          (To_Pointer (Handle), Raw (0)'Unchecked_Access, Error'Unchecked_Access);
      Check (Code, Error);
   end Median_Set_Radius;

   procedure Threshold_Set
     (Handle : System.Address; Lower, Upper, Inside_Value, Outside_Value : Long_Float)
   is
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
   begin
      Require (Handle);
      Code :=
        itklib_threshold_set
          (To_Pointer (Handle), Interfaces.C.double (Lower),
           Interfaces.C.double (Upper), Interfaces.C.double (Inside_Value),
           Interfaces.C.double (Outside_Value), Error'Unchecked_Access);
      Check (Code, Error);
   end Threshold_Set;

   procedure Rescale_Set_Output_Range
     (Handle : System.Address; Minimum, Maximum : Long_Float)
   is
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
   begin
      Require (Handle);
      Code :=
        itklib_rescale_set_output_range
          (To_Pointer (Handle), Interfaces.C.double (Minimum),
           Interfaces.C.double (Maximum), Error'Unchecked_Access);
      Check (Code, Error);
   end Rescale_Set_Output_Range;

   procedure Shrink_Set_Factors (Handle : System.Address; Factors : Extent_Array) is
      Raw : C_U64_Array (0 .. Factors'Length - 1);
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
   begin
      Require (Handle);
      Copy_U64 (Factors, Raw);
      Code :=
        itklib_shrink_set_factors
          (To_Pointer (Handle), Raw (0)'Unchecked_Access, Error'Unchecked_Access);
      Check (Code, Error);
   end Shrink_Set_Factors;

   procedure Resample_Configure
     (Handle : System.Address; Extent : Extent_Array; Spacing, Origin : Double_Array;
      Direction : Double_Array; Default_Pixel : Long_Float)
   is
      Raw_Size : C_U64_Array (0 .. Extent'Length - 1);
      Raw_Spacing : C_F64_Array (0 .. Spacing'Length - 1);
      Raw_Origin : C_F64_Array (0 .. Origin'Length - 1);
      Raw_Direction : C_F64_Array (0 .. Direction'Length - 1);
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
   begin
      Require (Handle);
      Copy_U64 (Extent, Raw_Size);
      Copy_F64 (Spacing, Raw_Spacing);
      Copy_F64 (Origin, Raw_Origin);
      Copy_F64 (Direction, Raw_Direction);
      Code :=
        itklib_resample_configure
          (To_Pointer (Handle), Raw_Size (0)'Unchecked_Access,
           Raw_Spacing (0)'Unchecked_Access, Raw_Origin (0)'Unchecked_Access,
           Raw_Direction (0)'Unchecked_Access, Interfaces.C.double (Default_Pixel),
           Error'Unchecked_Access);
      Check (Code, Error);
   end Resample_Configure;

   procedure Resample_Set_Uniform_Scale (Handle : System.Address; Scale : Long_Float) is
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
   begin
      Require (Handle);
      Code :=
        itklib_resample_set_uniform_scale
          (To_Pointer (Handle), Interfaces.C.double (Scale), Error'Unchecked_Access);
      Check (Code, Error);
   end Resample_Set_Uniform_Scale;

   procedure Flip_Set_Axes
     (Handle : System.Address; Axes : Extent_Array; About_Origin : Boolean)
   is
      Raw : array (0 .. Axes'Length - 1) of aliased Interfaces.C.int :=
        (others => 0);
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
      Flag : Interfaces.C.int := 0;
   begin
      Require (Handle);
      for K in Axes'Range loop
         if Axes (K) /= Interfaces.Unsigned_64'(0) then
            Raw (K - Axes'First) := 1;
         end if;
      end loop;
      if About_Origin then
         Flag := 1;
      end if;
      Code :=
        itklib_flip_set_axes
          (To_Pointer (Handle), Raw (0)'Unchecked_Access, Flag,
           Error'Unchecked_Access);
      Check (Code, Error);
   end Flip_Set_Axes;

   procedure Extract_Set_Region
     (Handle : System.Address; Start : Index_Array; Extent : Extent_Array)
   is
      Raw_Index : C_I64_Array (0 .. Start'Length - 1);
      Raw_Size : C_U64_Array (0 .. Extent'Length - 1);
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
   begin
      Require (Handle);
      for K in Start'Range loop
         Raw_Index (K - Start'First) := Start (K);
      end loop;
      Copy_U64 (Extent, Raw_Size);
      Code :=
        itklib_extract_set_region
          (To_Pointer (Handle), Raw_Index (0)'Unchecked_Access,
           Raw_Size (0)'Unchecked_Access, Error'Unchecked_Access);
      Check (Code, Error);
   end Extract_Set_Region;

   procedure Gradient_Set_Use_Image_Spacing
     (Handle : System.Address; Enabled : Boolean)
   is
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
      Flag : Interfaces.C.int := 0;
   begin
      Require (Handle);
      if Enabled then
         Flag := 1;
      end if;
      Code :=
        itklib_gradient_set_use_image_spacing
          (To_Pointer (Handle), Flag, Error'Unchecked_Access);
      Check (Code, Error);
   end Gradient_Set_Use_Image_Spacing;

   procedure Statistics_Get
     (Handle : System.Address; Minimum, Maximum, Mean : out Long_Float)
   is
      Raw_Min : aliased Interfaces.C.double := 0.0;
      Raw_Max : aliased Interfaces.C.double := 0.0;
      Raw_Mean : aliased Interfaces.C.double := 0.0;
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
   begin
      Require (Handle);
      Code :=
        itklib_statistics_get
          (To_Pointer (Handle), Raw_Min'Unchecked_Access, Raw_Max'Unchecked_Access,
           Raw_Mean'Unchecked_Access, Error'Unchecked_Access);
      Check (Code, Error);
      Minimum := Long_Float (Raw_Min);
      Maximum := Long_Float (Raw_Max);
      Mean := Long_Float (Raw_Mean);
   end Statistics_Get;

   procedure Modified (Process : System.Address) is
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
   begin
      Require (Process);
      Code := itklib_modified (To_Pointer (Process), Error'Unchecked_Access);
      Check (Code, Error);
   end Modified;

   procedure Update_Largest_Possible_Region (Process : System.Address) is
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
   begin
      Require (Process);
      Code :=
        itklib_update_largest_possible_region
          (To_Pointer (Process), Error'Unchecked_Access);
      Check (Code, Error);
   end Update_Largest_Possible_Region;

   procedure Set_Number_Of_Work_Units (Process : System.Address; Count : Positive) is
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
   begin
      Require (Process);
      Code :=
        itklib_set_number_of_work_units
          (To_Pointer (Process), Interfaces.C.unsigned (Count), Error'Unchecked_Access);
      Check (Code, Error);
   end Set_Number_Of_Work_Units;

   procedure Gaussian_Set_Maximum_Error
     (Handle : System.Address; Maximum_Error : Double_Array)
   is
      Raw : C_F64_Array (0 .. Maximum_Error'Length - 1);
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
   begin
      Require (Handle);
      Copy_F64 (Maximum_Error, Raw);
      Code :=
        itklib_discrete_gaussian_set_maximum_error
          (To_Pointer (Handle), Raw (0)'Unchecked_Access, Error'Unchecked_Access);
      Check (Code, Error);
   end Gaussian_Set_Maximum_Error;

   procedure Image_Buffer_Lock (Handle : System.Address) is
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
   begin
      Require (Handle);
      Code := itklib_image_buffer_lock (To_Pointer (Handle), Error'Unchecked_Access);
      Check (Code, Error);
   end Image_Buffer_Lock;

   procedure Image_Buffer_Unlock (Handle : System.Address) is
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
   begin
      Require (Handle);
      Code :=
        itklib_image_buffer_unlock (To_Pointer (Handle), Error'Unchecked_Access);
      Check (Code, Error);
   end Image_Buffer_Unlock;

   procedure Image_Disconnect (Handle : System.Address) is
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
   begin
      Require (Handle);
      Code := itklib_image_disconnect (To_Pointer (Handle), Error'Unchecked_Access);
      Check (Code, Error);
   end Image_Disconnect;

   procedure Image_Index_To_Physical
     (Handle : System.Address; Index : Index_Array; Point : out Double_Array)
   is
      Raw_Index : C_I64_Array (0 .. Index'Length - 1);
      Raw_Point : C_F64_Array (0 .. Point'Length - 1);
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
   begin
      Require (Handle);
      for K in Index'Range loop
         Raw_Index (K - Index'First) := Index (K);
      end loop;
      Code :=
        itklib_image_index_to_physical
          (To_Pointer (Handle), Raw_Index (0)'Unchecked_Access,
           Raw_Point (0)'Unchecked_Access, Error'Unchecked_Access);
      Check (Code, Error);
      for K in Point'Range loop
         Point (K) := Raw_Point (K - Point'First);
      end loop;
   end Image_Index_To_Physical;

   procedure Image_Physical_To_Index
     (Handle : System.Address; Point : Double_Array; Index : out Index_Array)
   is
      Raw_Point : C_F64_Array (0 .. Point'Length - 1);
      Raw_Index : C_I64_Array (0 .. Index'Length - 1);
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
   begin
      Require (Handle);
      Copy_F64 (Point, Raw_Point);
      Code :=
        itklib_image_physical_to_index
          (To_Pointer (Handle), Raw_Point (0)'Unchecked_Access,
           Raw_Index (0)'Unchecked_Access, Error'Unchecked_Access);
      Check (Code, Error);
      for K in Index'Range loop
         Index (K) := Raw_Index (K - Index'First);
      end loop;
   end Image_Physical_To_Index;

end Itklib.Thin;
