classdef GiDImageCapturer < handle
    
    properties (Access = private)
        resultsFile        
        inputFileName
        outPutImageName
        gidPath 
        swanPath
        pathTcl
        outPutFolderPath
        outputImageName
    end
    
    methods (Access = public)
        
        function obj = GiDImageCapturer(cParams)
            obj.init(cParams);
            obj.createPathNames();
                   obj.writeCallGiDTclFile();                 
        end
        
        function capture(obj)
            obj.captureImage();
            obj.cropImage();               
        end
        
    end
    
    methods (Access = private)
        
        function init(obj,cParams)
            obj.resultsFile     = cParams.fileName;     
            obj.outPutImageName = cParams.outPutImageName;
            obj.inputFileName   = cParams.inputFileName;
            obj.swanPath = '/home/alex/git-repos/Swan/';
            %obj.gidPath = '/home/alex/GiDx64/gid14.0.3/';
            %obj.gidPath = '/home/alex/GiDx64/14.1.6d/';                                   
            obj.gidPath = '/home/alex/GiDx64/14.1.9d/';
        end
        
        function createPathNames(obj)
            obj.pathTcl = [obj.swanPath,'PostProcess/ImageCapturer/'];
            obj.outPutFolderPath = [obj.swanPath,'Output/',obj.resultsFile,'/'];
            obj.outputImageName = [obj.outPutImageName];            
        end
        
        function writeCallGiDTclFile(obj)
            tclFile = 'callGiDCapturer.tcl';
            obj.inputFileName = char(obj.inputFileName);
            %stlFileTocall = 'CaptureImage.tcl';
           % stlFileTocall = 'CaptureImage3.tcl';
            stlFileTocall = 'CaptureImageColor.tcl';
          %  stlFileTocall = 'CaptureSmoothImageColor.tcl';

            
            fid = fopen([obj.pathTcl,tclFile],'w+');
            fprintf(fid,['set path "',obj.pathTcl,'"\n']);
            fprintf(fid,['set tclFile "',stlFileTocall,'"\n']);
            fprintf(fid,['source $path$tclFile \n']);
            fprintf(fid,['set output ',obj.outputImageName,' \n']);
            fprintf(fid,['set inputFile ',obj.inputFileName,'\n']);
            fprintf(fid,['CaptureImage $inputFile $output \n']);
            fclose(fid);
        end        
        
        function captureImage(obj)
            tclFile = [obj.pathTcl,'callGiDCapturer.tcl"'];
            command = [obj.gidPath,'gid_offscreen -offscreen -t "source ',tclFile];
            system(command);            
        end
        
        function cropImage(obj)
            inputImage  = [' ',obj.outputImageName,'.png'];
            outPutImage = inputImage;
            %convert     = 'convert -crop 700x700+0+0 -gravity Center';
            convert     = 'convert -crop 500x500+0+0 -gravity Center';                        
            %convert     = 'convert -crop 1500x1500+0+0 -gravity Center';
            command = strcat(convert,' ',inputImage,' ',outPutImage);
            system(command);
        end
        
    end
    
end