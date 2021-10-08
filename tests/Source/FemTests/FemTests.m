classdef FemTests < testRunner
    
    
    properties (Access = protected)
        FieldOfStudy = 'FEM'
        tests
    end
    
    methods (Access = public)
        function obj = FemTests()
            obj@testRunner();
        end
    end
    
    methods (Access = protected)
        function loadTests(obj)
            obj.tests = {...
                'testPrincipalDirection2D';
                'testPrincipalDirection3D';                
                };
        end
    end
    
end

