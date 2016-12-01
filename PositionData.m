classdef PositionData < event.EventData
    % ---------------------------------------------------------------------
    % TouchInterface
    % Han Lab
    % 7/11/2011
    % Mark Bucklin & Chun Hin Tang
    % ---------------------------------------------------------------------
    %
    % This class is used to attach x,y position data to a touch, move, or
    % lift event from the TOUCHINTERFACE class. The data will be in 2x1
    % vector format [x;y].
    %
    % See Also TOUCHDISPLAY RECTANGLE TOUCHINTERFACE
    
    
   properties
      position
   end
   
   
   
   methods
      function eventData = PositionData(varargin)
          eventData.position = [varargin{:}];
          eventData.position = eventData.position(:);
      end
   end
   
end
